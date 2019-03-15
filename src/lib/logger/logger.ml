open Core
open Async

module Level = struct
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving bin_io, sexp, compare, show {with_path= false}]

  let of_string str =
    try Ok (t_of_sexp (Sexp.Atom str)) with Sexp.Of_sexp_error (err, _) ->
      Error (Exn.to_string err)

  let to_yojson t = `String (show t)

  let of_yojson json = of_string @@ Yojson.Safe.Util.to_string json
end

module Attribute = struct
  type t = string * string

  let ( ^= ) k v = (k, v)
end

(* Core modules extended with Yojson converters *)
module Time = struct
  include Time

  let to_yojson t = `String (Time.to_string_abs t ~zone:Zone.utc)

  let of_yojson json =
    json |> Yojson.Safe.Util.to_string |> fun s -> Ok (Time.of_string s)
end

module Pid = struct
  include Pid

  let to_yojson t =
    let pid_string = Pid.to_string t in
    `Int (int_of_string pid_string)

  let of_yojson json =
    json |> Yojson.Safe.Util.to_int
    |> fun n -> Ok (Pid.of_string (string_of_int n))
end

module Message = struct
  type t =
    { attributes: (string * string) list
    ; path: string list
    ; level: Level.t
    ; pid: Pid.t
    ; host: string
    ; timestamp: Time.t
    ; location: string option
    ; message: string }
  [@@deriving sexp, bin_io, yojson]

  let escape_string str =
    String.to_list str
    |> List.bind ~f:(function
         | '"' -> ['\\'; '"']
         | '\\' -> ['\\'; '\\']
         | c -> [c] )
    |> String.of_char_list

  (* escape strings for json formatting *)
  let escape m =
    { m with
      attributes=
        List.map m.attributes ~f:(fun (k, v) ->
            (escape_string k, escape_string v) )
        (* we assume the path, host and location do not need to be escaped *)
        (* ; path= List.map m.path ~f:escape_string *)
        (* ; host= escape_string m.host *)
        (* ; location= Option.map m.location ~f:escape_string *)
    ; message= escape_string m.message }
end

type t =
  { null: bool
  ; attributes: (string * string) list
  ; pid: Pid.t
  ; host: string
  ; path: string list }
[@@deriving bin_io]

(* flag is set on daemon startup
 * running the daemon sets this option, but
 * other code run during unit tests does logging without
 * setting the option, precluding use of Set_once here *)

let sexp_logging = ref false

let set_sexp_logging b = sexp_logging := b

let get_sexp_logging () = !sexp_logging

let create () =
  { attributes= []
  ; null= false
  ; pid= Unix.getpid ()
  ; host= Unix.gethostname ()
  ; path= [] }

let null () =
  let l = create () in
  {l with null= true}

let log ~level ?loc ?(attrs = []) t fmt =
  ksprintf
    (fun message ->
      if t.null then ifprintf stdout ""
      else
        let m : Message.t =
          { attributes= attrs
          ; path= t.path
          ; pid= t.pid
          ; host= t.host
          ; timestamp= Time.now ()
          ; level
          ; message
          ; location= loc }
        in
        let output =
          if get_sexp_logging () then
            (* S-expression output *)
            Sexp.to_string_mach (Message.sexp_of_t m)
          else
            (* JSON output *)
            Yojson.Safe.to_string (Message.to_yojson (Message.escape m))
        in
        printf "%s\n" output )
    fmt

let extend t attrs = {t with attributes= t.attributes @ attrs}

let child t s =
  { t with
    path= s :: t.path
  ; attributes= t.attributes @ [("module", s); (sprintf "module-%s" s, "true")]
  }

type 'a logger =
     ?loc:string
  -> ?attrs:Attribute.t list
  -> t
  -> ('a, unit, string, unit) format4
  -> 'a

let trace ?loc ?attrs t fmt = log ~level:Trace ?loc ?attrs t fmt

let debug ?loc ?attrs t fmt = log ~level:Debug ?loc ?attrs t fmt

let info ?loc ?attrs t fmt = log ~level:Info ?loc ?attrs t fmt

let warn ?loc ?attrs t fmt = log ~level:Warn ?loc ?attrs t fmt

let error ?loc ?attrs t fmt = log ~level:Error ?loc ?attrs t fmt

let fatal ?loc ?attrs t fmt = log ~level:Fatal ?loc ?attrs t fmt

let faulty_peer ?loc ?attrs t fmt = log ~level:Faulty_peer ?loc ?attrs t fmt
