open Core
open Async
open Coda_worker
open Coda_main

let name = "coda-shared-prefix-test"

let main who_proposes () =
  let log = Logger.create () in
  let log = Logger.child log name in
  let n = 2 in
  let proposers i = if i = who_proposes then Some i else None in
  let snark_work_public_keys i = None in
  let%bind testnet =
    Coda_worker_testnet.test log n proposers snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  after (Time.Span.of_sec 30.)

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open who_proposes =
       flag "who-proposes" ~doc:"ID node number which will be proposing"
         (required int)
     in
     main who_proposes)
