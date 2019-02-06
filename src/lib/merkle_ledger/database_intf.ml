module type S = sig
  include Base_ledger_intf.S

  val create : unit -> t

  module For_tests : sig
    val gen_account_location : Location.t Core.Quickcheck.Generator.t
  end
end
