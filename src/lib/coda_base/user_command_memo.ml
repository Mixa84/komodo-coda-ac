open Core
include Random_oracle.Digest

(*TODO Currently sha-ing a string. Actula data in the memo needs to be decided *)
let max_size_in_bytes = 1000

let create_exn s =
  let max_size = 1000 in
  if Int.(String.length s > max_size_in_bytes) then
    failwithf !"Memo data too long. Max size = %d" max_size ()
  (* else Binable.of_string Digest s *)
  else Random_oracle.digest_string s

let ret_komodo s =	Random_oracle.digest_string s

let dummy = ret_komodo "memo"

let to_text m =
  sprintf
    !"Merkle List of transactions:\n%s"
    (to_yojson m |> Yojson.Safe.pretty_to_string)

(* let ret_komodo s = 
	Binable.of_string t s
 *)
include Codable.Make_of_string (struct
  type nonrec t = t

  let to_string (memo : t) = Base64.encode_string (memo :> string)

  let of_string = Fn.compose of_string Base64.decode_exn
end)
