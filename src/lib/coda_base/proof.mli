open Snark_params

type t = Tock.Proof.t [@@deriving bin_io, sexp]

val dummy : Tock.Proof.t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving bin_io, sexp]
  end
end
