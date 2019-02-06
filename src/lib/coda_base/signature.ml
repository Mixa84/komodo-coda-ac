open Core

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Snark_params.Tock.Field.t * Snark_params.Tock.Field.t
      [@@deriving sexp, eq, compare, hash, bin_io]
    end

    let to_base64 t = Binable.to_string (module T) t |> B64.encode

    let of_base64_exn s = B64.decode s |> Binable.of_string (module T)

    include T

    include Codable.Make_of_string (struct
      type nonrec t = t

      let to_string = to_base64

      let of_string = of_base64_exn
    end)
  end
end

include Stable.V1
open Snark_params.Tick

type var = Inner_curve.Scalar.var * Inner_curve.Scalar.var

let dummy : t = Inner_curve.Scalar.(one, one)
