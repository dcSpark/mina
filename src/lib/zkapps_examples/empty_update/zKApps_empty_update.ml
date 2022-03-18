open Core_kernel
open Pickles_types.Hlist
open Snark_params.Tick
open Currency
open Signature_lib
open Mina_base

module Party_under_construction = struct
  type t = { public_key : Public_key.Compressed.t; token_id : Token_id.t }

  let create ~public_key ?(token_id = Token_id.default) () =
    { public_key; token_id }

  let to_party (t : t) : Party.Predicated.t =
    { body =
        { public_key = t.public_key
        ; token_id = t.token_id
        ; update =
            { app_state = [ Keep; Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
            ; delegate = Keep
            ; verification_key = Keep
            ; permissions = Keep
            ; snapp_uri = Keep
            ; token_symbol = Keep
            ; timing = Keep
            ; voting_for = Keep
            }
        ; balance_change = { magnitude = Amount.zero; sgn = Pos }
        ; increment_nonce = false
        ; events = []
        ; sequence_events = []
        ; call_data = Field.zero
        ; call_depth = 0
        ; protocol_state =
            { snarked_ledger_hash = Ignore
            ; timestamp = Ignore
            ; blockchain_length = Ignore
            ; min_window_density = Ignore
            ; last_vrf_output = ()
            ; total_currency = Ignore
            ; global_slot_since_hard_fork = Ignore
            ; global_slot_since_genesis = Ignore
            ; staking_epoch_data =
                { ledger =
                    { Epoch_ledger.Poly.hash = Ignore; total_currency = Ignore }
                ; seed = Ignore
                ; start_checkpoint = Ignore
                ; lock_checkpoint = Ignore
                ; epoch_length = Ignore
                }
            ; next_epoch_data =
                { ledger =
                    { Epoch_ledger.Poly.hash = Ignore; total_currency = Ignore }
                ; seed = Ignore
                ; start_checkpoint = Ignore
                ; lock_checkpoint = Ignore
                ; epoch_length = Ignore
                }
            }
        ; use_full_commitment = false
        }
    ; predicate =
        Full
          { balance = Ignore
          ; nonce = Ignore
          ; receipt_chain_hash = Ignore
          ; public_key = Ignore
          ; delegate = Ignore
          ; state =
              [ Ignore; Ignore; Ignore; Ignore; Ignore; Ignore; Ignore; Ignore ]
          ; sequence_state = Ignore
          ; proved_state = Ignore
          }
    }

  module In_circuit = struct
    type t =
      { public_key : Public_key.Compressed.var; token_id : Token_id.Checked.t }

    let create ~public_key ?(token_id = Token_id.(Checked.constant default)) ()
        =
      { public_key; token_id }

    let to_party (t : t) : Party.Predicated.Checked.t =
      (* TODO: Don't do this. *)
      let var_of_t (type var value) (typ : (var, value) Typ.t) (x : value) : var
          =
        Snarky_backendless.Typ_monads.Store.run (typ.store x) Field.Var.constant
      in
      { body =
          { public_key = t.public_key
          ; token_id = t.token_id
          ; update =
              var_of_t (Party.Update.typ ())
                { app_state = [ Keep; Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
                ; delegate = Keep
                ; verification_key = Keep
                ; permissions = Keep
                ; snapp_uri = Keep
                ; token_symbol = Keep
                ; timing = Keep
                ; voting_for = Keep
                }
          ; balance_change =
              var_of_t Amount.Signed.typ { magnitude = Amount.zero; sgn = Pos }
          ; increment_nonce = Boolean.false_
          ; events = var_of_t Snapp_account.Events.typ []
          ; sequence_events = var_of_t Snapp_account.Events.typ []
          ; call_data = Field.Var.constant Field.zero
          ; call_depth = Run.As_prover.Ref.create (fun () -> 0)
          ; protocol_state =
              var_of_t Snapp_predicate.Protocol_state.typ
                { snarked_ledger_hash = Ignore
                ; timestamp = Ignore
                ; blockchain_length = Ignore
                ; min_window_density = Ignore
                ; last_vrf_output = ()
                ; total_currency = Ignore
                ; global_slot_since_hard_fork = Ignore
                ; global_slot_since_genesis = Ignore
                ; staking_epoch_data =
                    { ledger =
                        { Epoch_ledger.Poly.hash = Ignore
                        ; total_currency = Ignore
                        }
                    ; seed = Ignore
                    ; start_checkpoint = Ignore
                    ; lock_checkpoint = Ignore
                    ; epoch_length = Ignore
                    }
                ; next_epoch_data =
                    { ledger =
                        { Epoch_ledger.Poly.hash = Ignore
                        ; total_currency = Ignore
                        }
                    ; seed = Ignore
                    ; start_checkpoint = Ignore
                    ; lock_checkpoint = Ignore
                    ; epoch_length = Ignore
                    }
                }
          ; use_full_commitment = Boolean.false_
          }
      ; predicate =
          var_of_t (Party.Predicate.typ ())
            (Full
               { balance = Ignore
               ; nonce = Ignore
               ; receipt_chain_hash = Ignore
               ; public_key = Ignore
               ; delegate = Ignore
               ; state =
                   [ Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ; Ignore
                   ]
               ; sequence_state = Ignore
               ; proved_state = Ignore
               })
      }
  end
end

(* TODO: Pickles should allow you to inject auxiliary values / handlers. *)
let public_key = ref None

(* TODO: Should be able to *return* stmt instead of consuming it.
         Modify snarky to do this.
*)
let main ([] : _ H1.T(Id).t)
    ({ transaction; at_party } : Snapp_statement.Checked.t) :
    _ H1.T(E01(Pickles.Inductive_rule.B)).t =
  let party =
    Party_under_construction.In_circuit.create
      ~public_key:(Option.value_exn !public_key)
      ~token_id:Token_id.(Checked.constant default)
      ()
  in
  let party = Party_under_construction.In_circuit.to_party party in
  let returned_transaction = Party.Predicated.Checked.digest party in
  let returned_at_party =
    (* TODO: This should be returned from
             [Party_under_construction.In_circuit.to_party].
    *)
    Field.Var.constant Parties.Call_forest.empty
  in
  Run.Field.Assert.equal returned_transaction transaction ;
  Run.Field.Assert.equal returned_at_party at_party ;
  []

(* TODO: This shouldn't exist, the circuit should just return the requisite
         values.
*)
let main_value ([] : _ H1.T(Id).t) (_ : Snapp_statement.t) :
    _ H1.T(E01(Core_kernel.Bool)).t =
  []

let rule : _ Pickles.Inductive_rule.t =
  { identifier = "Empty update"; prevs = []; main; main_value }
