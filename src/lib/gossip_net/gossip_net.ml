open Core
open Async
open Pipe_lib
open Network_peer
open Kademlia
open O1trace
module Membership = Membership.Haskell

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module type Message_intf = sig
  type content

  type msg

  include
    Versioned_rpc.Both_convert.One_way.S
    with type callee_msg := msg
     and type caller_msg := msg

  val content : msg -> content

  val sender : msg -> Envelope.Sender.t
end

module type Config_intf = sig
  type t =
    { timeout: Time.Span.t
    ; target_peer_count: int
    ; initial_peers: Host_and_port.t list
    ; me: Peer.t
    ; conf_dir: string
    ; parent_log: Logger.t
    ; trust_system: Coda_base.Trust_system.t }
  [@@deriving make]
end

module type S = sig
  type content

  type msg

  type t =
    { timeout: Time.Span.t
    ; log: Logger.t
    ; target_peer_count: int
    ; broadcast_writer: msg Linear_pipe.Writer.t
    ; received_reader: content Envelope.Incoming.t Strict_pipe.Reader.t
    ; me: Peer.t
    ; peers: Peer.Hash_set.t }

  module Config : Config_intf

  val create :
    Config.t -> Host_and_port.t Rpc.Implementation.t list -> t Deferred.t

  val received : t -> content Envelope.Incoming.t Strict_pipe.Reader.t

  val broadcast : t -> msg Linear_pipe.Writer.t

  val broadcast_all :
    t -> msg -> (unit -> [`Done | `Continue] Deferred.t) Staged.t

  val random_peers : t -> int -> Peer.t list

  val random_peers_except : t -> int -> except:Peer.Hash_set.t -> Peer.t list

  val peers : t -> Peer.t list

  val query_peer :
    t -> Peer.t -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t

  val query_random_peers :
    t -> int -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t List.t
end

module Make (Message : Message_intf) :
  S with type msg := Message.msg and type content := Message.content = struct
  type t =
    { timeout: Time.Span.t
    ; log: Logger.t
    ; target_peer_count: int
    ; broadcast_writer: Message.msg Linear_pipe.Writer.t
    ; received_reader: Message.content Envelope.Incoming.t Strict_pipe.Reader.t
    ; me: Peer.t
    ; peers: Peer.Hash_set.t }

  module Config = struct
    type t =
      { timeout: Time.Span.t
      ; target_peer_count: int
      ; initial_peers: Host_and_port.t list
      ; me: Peer.t
      ; conf_dir: string
      ; parent_log: Logger.t
      ; trust_system: Coda_base.Trust_system.t }
    [@@deriving make]
  end

  (* OPTIMIZATION: use fast n choose k implementation - see python or old flow code *)
  let random_sublist xs n = List.take (List.permute xs) n

  let create_connection_with_menu peer r w =
    match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> peer) with
    | Error exn -> return (Or_error.of_exn exn)
    | Ok conn -> Versioned_rpc.Connection_with_menu.create conn

  let try_call_rpc t peer dispatch query =
    try_with (fun () ->
        Tcp.with_connection (Tcp.Where_to_connect.of_host_and_port peer)
          ~timeout:t.timeout (fun _ r w ->
            create_connection_with_menu peer r w
            >>=? fun conn -> dispatch conn query ) )
    >>| function
    | Ok (Ok result) -> Ok result
    | Ok (Error exn) -> Error exn
    | Error exn -> Or_error.of_exn exn

  let broadcast_selected t peers msg =
    let peers =
      List.map peers ~f:(fun peer -> Peer.to_communications_host_and_port peer)
    in
    let send peer =
      try_call_rpc t peer
        (fun conn m -> return (Message.dispatch_multi conn m))
        msg
    in
    trace_event "broadcasting message" ;
    Deferred.List.iter ~how:`Parallel peers ~f:(fun p ->
        match%map send p with
        | Ok () -> ()
        | Error e -> Logger.error t.log "%s" (Error.to_string_hum e) )

  let broadcast_random t n msg =
    let selected_peers = random_sublist (Hash_set.to_list t.peers) n in
    broadcast_selected t selected_peers msg

  let create (config : Config.t)
      (implementations : Host_and_port.t Rpc.Implementation.t list) =
    let log = Logger.child config.parent_log __MODULE__ in
    trace_task "gossip net" (fun () ->
        let%map membership =
          match%map
            trace_task "membership" (fun () ->
                Membership.connect ~initial_peers:config.initial_peers
                  ~me:config.me ~conf_dir:config.conf_dir ~parent_log:log
                  ~trust_system:config.trust_system )
          with
          | Ok membership -> membership
          | Error e ->
              failwith
                (Printf.sprintf "Failed to connect to kademlia process: %s\n"
                   (Error.to_string_hum e))
        in
        let peer_events = Membership.changes membership in
        let broadcast_reader, broadcast_writer = Linear_pipe.create () in
        let received_reader, received_writer =
          Strict_pipe.create (Buffered (`Capacity 64, `Overflow Drop_head))
        in
        let t =
          { timeout= config.timeout
          ; log
          ; target_peer_count= config.target_peer_count
          ; broadcast_writer
          ; received_reader
          ; me= config.me
          ; peers= Peer.Hash_set.create () }
        in
        trace_task "rebroadcasting messages" (fun () ->
            don't_wait_for
              (Linear_pipe.iter_unordered ~max_concurrency:64 broadcast_reader
                 ~f:(fun m ->
                   Logger.trace log "broadcasting message" ;
                   broadcast_random t t.target_peer_count m )) ) ;
        let implementations =
          let implementations =
            Versioned_rpc.Menu.add
              ( Message.implement_multi
                  (fun _client_host_and_port ~version:_ msg ->
                    (* TODO: maybe check client host matches IP in msg, punish if
                        mismatch due to forgery
                     *)
                    Strict_pipe.Writer.write received_writer
                      (Envelope.Incoming.wrap ~data:(Message.content msg)
                         ~sender:(Message.sender msg)) )
              @ implementations )
          in
          Rpc.Implementations.create_exn ~implementations
            ~on_unknown_rpc:`Close_connection
        in
        trace_task "peer events" (fun () ->
            Linear_pipe.iter_unordered ~max_concurrency:64 peer_events
              ~f:(function
              | Connect peers ->
                  Logger.info log "Some peers connected %s"
                    (List.sexp_of_t Peer.sexp_of_t peers |> Sexp.to_string_hum) ;
                  List.iter peers ~f:(fun peer -> Hash_set.add t.peers peer) ;
                  Deferred.unit
              | Disconnect peers ->
                  Logger.info log "Some peers disconnected %s"
                    (List.sexp_of_t Peer.sexp_of_t peers |> Sexp.to_string_hum) ;
                  List.iter peers ~f:(fun peer -> Hash_set.remove t.peers peer) ;
                  Deferred.unit )
            |> ignore ) ;
        ignore
          (Tcp.Server.create
             ~on_handler_error:
               (`Call
                 (fun _ exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
             (Tcp.Where_to_listen.of_port config.me.Peer.communication_port)
             (fun client reader writer ->
               Rpc.Connection.server_with_close reader writer ~implementations
                 ~connection_state:(fun _ ->
                   (* connection state is the client's IP and ephemeral port when
                 connecting to the server over TCP; the ephemeral port is
                 distinct from the client's discovery and communication ports
              *)
                   Socket.Address.Inet.to_host_and_port client )
                 ~on_handshake_error:
                   (`Call
                     (fun exn ->
                       Logger.error log "%s" (Exn.to_string_mach exn) ;
                       Deferred.unit )) )) ;
        t )

  let received t = t.received_reader

  let broadcast t = t.broadcast_writer

  let peers t = Hash_set.to_list t.peers

  let broadcast_all t msg =
    let to_broadcast = ref (List.permute (Hash_set.to_list t.peers)) in
    stage (fun () ->
        let selected = List.take !to_broadcast t.target_peer_count in
        to_broadcast := List.drop !to_broadcast t.target_peer_count ;
        let%map () = broadcast_selected t selected msg in
        if List.length !to_broadcast = 0 then `Done else `Continue )

  let random_peers t n = random_sublist (Hash_set.to_list t.peers) n

  let random_peers_except t n ~(except : Peer.Hash_set.t) =
    let new_peers = Hash_set.(diff t.peers except |> to_list) in
    random_sublist new_peers n

  let query_peer t (peer : Peer.t) rpc query =
    Logger.trace t.log !"Querying peer %{sexp: Peer.t}" peer ;
    let peer = Peer.to_communications_host_and_port peer in
    try_call_rpc t peer rpc query

  let query_random_peers t n rpc query =
    let peers = random_sublist (Hash_set.to_list t.peers) n in
    Logger.trace t.log !"Querying random peers: %{sexp: Peer.t list}" peers ;
    List.map peers ~f:(fun peer -> query_peer t peer rpc query)
end
