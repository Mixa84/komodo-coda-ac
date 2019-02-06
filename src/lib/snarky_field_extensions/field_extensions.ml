module Make (F : Intf.Basic) = struct
  open F.Impl
  open Let_syntax
  open F

  let typ = F.typ

  let constant = F.constant

  let scale = F.scale

  let assert_r1cs = F.assert_r1cs

  let ( + ) = F.( + )

  let ( - ) = F.( - )

  let negate = F.negate

  let zero = constant Unchecked.zero

  let one = constant Unchecked.one

  let assert_square =
    match assert_square with
    | `Custom f -> f
    | `Define -> fun a a2 -> assert_r1cs a a a2

  let ( * ) =
    match ( * ) with
    | `Custom f -> f
    | `Define ->
        fun x y ->
          let%bind res =
            provide_witness typ
              As_prover.(map2 (read typ x) (read typ y) ~f:Unchecked.( * ))
          in
          let%map () = assert_r1cs x y res in
          res

  let square =
    match square with
    | `Custom f -> f
    | `Define ->
        fun x ->
          let%bind res =
            provide_witness typ
              As_prover.(map (read typ x) ~f:Unchecked.square)
          in
          let%map () = assert_square x res in
          res

  let inv_exn =
    match inv_exn with
    | `Custom f -> f
    | `Define ->
        fun t ->
          let%bind res =
            provide_witness typ As_prover.(map (read typ t) ~f:Unchecked.inv)
          in
          let%map () = assert_r1cs t res one in
          res
end

module Make_applicative (F : Intf.S) (A : Intf.Applicative) = struct
  type t = F.t A.t

  type 'a t_ = 'a F.t_ A.t

  let constant = A.map ~f:F.constant

  let scale t x = A.map t ~f:(fun a -> F.scale a x)

  let scale' t x = A.map t ~f:(fun a -> F.scale x a)

  let negate t = A.map t ~f:F.negate

  let ( + ) = A.map2 ~f:F.( + )

  let ( - ) = A.map2 ~f:F.( - )
end

(* Given a field F and s : F (called [non_residue] below)
   such that x^2 - s does not have a root in F, construct
   the field F(sqrt(s)) = F[x] / (x^2 - s) *)
module E2
    (F : Intf.S) (Params : sig
        val non_residue : F.Unchecked.t

        val mul_by_non_residue : F.t -> F.t
    end) : Intf.S with module Impl = F.Impl = struct
  open Params

  module T = struct
    module Base = F
    module Impl = F.Impl
    open Impl
    open Let_syntax
    module Unchecked = Snarkette.Fields.Make_fp2 (F.Unchecked) (Params)

    module A = struct
      type 'a t = 'a * 'a

      let map (x, y) ~f = (f x, f y)

      let map2 (x1, y1) (x2, y2) ~f = (f x1 x2, f y1 y2)
    end

    (* A value [(a, b) : t] should be thought of as the field element
   a + b sqrt(s). Then all operations are just what follow algebraically. *)

    include Make_applicative (Base) (A)

    let typ = Typ.tuple2 F.typ F.typ

    (*
       (a + b sqrt(s))^2
       = a^2 + b^2 s + 2 a b sqrt(s)

       So it is clear that the second coordinate of the below definition is correct. Let's
       examine the first coordinate.

       t - ab - ab sqrt(s)
       = (a + b) (a + s b) - ab - s a b
       = a^2 + a b + s a b + s b^2 - a b - s a b
       = a^2 + s b^2

       so this is correct as well.
    *)
    let square (a, b) =
      let open F in
      let%map ab = a * b and t = (a + b) * (a + mul_by_non_residue b) in
      (t - ab - mul_by_non_residue ab, ab + ab)

    let assert_square (a, b) (a2, b2) =
      let open F in
      let ab = scale b2 Field.(Infix.(one / of_int 2)) in
      let%map () = assert_r1cs a b ab
      and () =
        assert_r1cs (a + b)
          (a + mul_by_non_residue b)
          (a2 + ab + mul_by_non_residue ab)
      in
      ()

    (*
       (a1 + b1 sqrt(s)) (a2 + b2 sqrt(s))
       = (a1 a2 + b1 b2 s) + (a2 b1 + a1 b2) sqrt(s)

       So it is clear that the first coordinate is correct. Let's examine the second
       coordinate.

       t - a1 a2 - b1 b2
       = (a1 + b1) (a2 + b2) - a1 a2 - b1 b2
       = a1 a2 + b2 b2 + a1 b2 + a2 b1 - a1 a2 - b1 b2
       = a1 b2 + a2 b1

       So this is correct as well.
    *)
    let ( * ) (a1, b1) (a2, b2) =
      let open F in
      let%map a = a1 * a2 and b = b1 * b2 and t = (a1 + b1) * (a2 + b2) in
      (a + mul_by_non_residue b, t - a - b)

    let assert_r1cs (a1, b1) (a2, b2) (a3, b3) =
      let open F in
      let%bind b = b1 * b2 in
      let a = a3 - mul_by_non_residue b in
      let%map () = assert_r1cs a1 a2 a
      and () = assert_r1cs (a1 + b1) (a2 + b2) (b3 + a + b) in
      ()

    let square = `Custom square

    let ( * ) = `Custom ( * )

    let inv_exn = `Define

    let assert_square = `Custom assert_square
  end

  include T
  include Make (T)
end

(* Given a prime order field F and s : F (called [non_residue] below)
   such that x^3 - s is irreducible, construct
   the field F(cube_root(s)) = F[x] / (x^3 - s).

   Let S = cube_root(s) in the following.
*)
module E3
    (F : Intf.S) (Params : sig
        val non_residue : F.Unchecked.t

        val frobenius_coeffs_c1 : F.Unchecked.t array

        val frobenius_coeffs_c2 : F.Unchecked.t array

        val mul_by_non_residue : F.t -> F.t
    end) : Intf.S with module Impl = F.Impl = struct
  module T = struct
    module Base = F
    module Unchecked = Snarkette.Fields.Make_fp3 (F.Unchecked) (Params)
    module Impl = F.Impl
    open Impl
    open Let_syntax

    module A = struct
      type 'a t = 'a * 'a * 'a

      let map (x, y, z) ~f = (f x, f y, f z)

      let map2 (x1, y1, z1) (x2, y2, z2) ~f = (f x1 x2, f y1 y2, f z1 z2)
    end

    include Make_applicative (Base) (A)

    let typ = Typ.tuple3 F.typ F.typ F.typ

    (*
       (a1 + S b1 + S^2 c1) (a2 + S b2 + S^2 c2)
       = a1 a2 + S a1 b2 + S^2 a1 c2
         + S b1 a2 + S^2 b1 b2 + S^3 b1 c2
         + S^2 c1 a2 + S^3 c1 b2 + S^4 c1 c2
       = a1 a2 + S a1 b2 + S^2 a1 c2
         + S b1 a2 + S^2 b1 b2 + s b1 c2
         + S^2 c1 a2 + s c1 b2 + s S c1 c2
       = (a1 a2 + s b1 c2 + s c1 b2)
       + S (a1 b2 + b1 a2 + s c1 c2)
       + S^2 (a1 c2 + c1 a2 + b1 b2)

       Let us examine the three coordinates in turn.

       First coordinate:
       a + s (t1 - b - c)
       = a1 a2 + s ( (b1 + c1) (b2 + c2) - b - c)
       = a1 a2 + s (b1 c2 + b2 c1)
       which is evidently correct.

       Second coordinate:
       t2 - a - b + s c
       (a1 + b1) (a2 + b2) - a - b + s c
       a1 b2 + b1 a2 + s c
       which is evidently correct.

       Third coordinate:
       t3 - a + b - c
       = (a1 + c1) (a2 + c2) - a + b - c
       = a1 c2 + c1 a2 + b
       which is evidently correct.
    *)
    let ( * ) (a1, b1, c1) (a2, b2, c2) =
      let open F in
      let%map a = a1 * a2
      and b = b1 * b2
      and c = c1 * c2
      and t1 = (b1 + c1) * (b2 + c2)
      and t2 = (a1 + b1) * (a2 + b2)
      and t3 = (a1 + c1) * (a2 + c2) in
      ( a + Params.mul_by_non_residue (t1 - b - c)
      , t2 - a - b + Params.mul_by_non_residue c
      , t3 - a + b - c )

    (*
       (a + S b + S^2 c)^2
       = a^2 + S a b + S^2 a c
       + S a b + S^2 b^2 + S^3 b c
       + S^2 a c + S^3 b c + S^4 c^2
       = a^2 + S a b + S^2 a c
       + S a b + S^2 b^2 + s b c
       + S^2 a c + s b c + S s c^2
       = (a^2 + 2 s b c)
       + S (2 a b + s c^2)
       + S^2 (b^2 + 2 a c)

       Let us examine the three coordinates in turn.

       First coordinate:
       s0 + s s3
       = a^2 + 2 s b c
       which is evidently correct.

       Second coordinate:
       s1 + s s4
       = 2 a b + s c^2
       which is evidently correct.

       Third coordinate:
       s1 + s2 + s3 - s0 - s4
       = 2 a b + (a - b + c)^2 + 2 b c - a^2 - c^2
       = 2 a b + a^2 - 2 a b + 2 a c - 2 b c + b^2 + c^2 + 2 b c - a^2 - c^2
       = 2 a c + b^2
       which is evidently correct.
    *)
    let square (a, b, c) =
      let open F in
      let%map s0 = square a
      and ab = a * b
      and bc = b * c
      and s2 = square (a - b + c)
      and s4 = square c in
      let s1 = ab + ab in
      let s3 = bc + bc in
      ( s0 + Params.mul_by_non_residue s3
      , s1 + Params.mul_by_non_residue s4
      , s1 + s2 + s3 - s0 - s4 )

    let assert_r1cs (a1, b1, c1) (a2, b2, c2) (a3, b3, c3) =
      let open F in
      let%bind b = b1 * b2 and c = c1 * c2 and t1 = (b1 + c1) * (b2 + c2) in
      let a = a3 - Params.mul_by_non_residue (t1 - b - c) in
      let%map () = assert_r1cs a1 a2 a
      and () =
        assert_r1cs (a1 + b1) (a2 + b2)
          (b3 + a + b - Params.mul_by_non_residue c)
      and () = assert_r1cs (a1 + c1) (a2 + c2) (c3 + a - b + c) in
      ()

    let square = `Custom square

    let ( * ) = `Custom ( * )

    let inv_exn = `Define

    let assert_square = `Define
  end

  include T
  include Make (T)
end
