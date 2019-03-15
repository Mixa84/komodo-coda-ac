open Core
open Async
open Coda_worker
open Coda_main

let name = "coda-block-production-test"

let main () =
  let log = Logger.create () in
  let log = Logger.child log name in
  let n = 1 in
  let snark_work_public_keys i = None in
  let%bind testnet =
    Coda_worker_testnet.test log n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  after (Time.Span.of_sec 30.)

let command =
  Command.async ~summary:"Test that blocks get produced"
    (Command.Param.return main)
