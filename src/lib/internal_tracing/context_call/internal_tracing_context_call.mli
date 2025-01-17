(** Helper module for setting the execution context call ID.

    Useful for being able to detect context switches when
    there are concurrent verifier/prover calls. *)

(** [with_call_id f] runs [f] in a context in which
    an unique identifier has been associated to the current call. *)
val with_call_id : (unit -> 'a) -> 'a

(** [get ()] returns current call ID bound to the current context (if any),
    or 0 *)
val get : unit -> int
