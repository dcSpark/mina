open Core_kernel
open Mina_transaction_logic
open Currency
open Mina_base
open Mina_numbers

type txn_result = (Account.Timing.t, Error.t) Result.t
[@@deriving compare, sexp]

let init_min_bal a =
  Option.value ~default:Balance.zero @@ Account.initial_minimum_balance a

let cliff_time a =
  Option.value ~default:Global_slot.zero @@ Account.cliff_time a

let final_vesting_slot ~initial_minimum_balance ~cliff_time ~cliff_amount
    ~vesting_period ~vesting_increment =
  let open Unsigned in
  let to_vest =
    Balance.(initial_minimum_balance - cliff_amount)
    |> Option.value_map ~default:UInt64.zero ~f:Balance.to_uint64
  in
  let incr = Amount.to_uint64 vesting_increment in
  let periods =
    let open UInt64 in
    let open Infix in
    (to_vest / incr) + if equal (rem to_vest incr) zero then zero else one
  in
  let open UInt32 in
  let open Infix in
  Global_slot.to_uint32 cliff_time
  + (UInt64.to_uint32 periods * Global_slot.to_uint32 vesting_period)
  |> Global_slot.of_uint32

let timing_final_vesting_slot = function
  | Account.Timing.Untimed ->
      Global_slot.zero
  | Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } ->
      final_vesting_slot ~initial_minimum_balance ~cliff_time ~cliff_amount
        ~vesting_period ~vesting_increment

(* These tests verify basic invariants of timed accounts' behaviour.
   This is done very simply by exercising the function which determines
   whether a transaction is valid. See the Account_timing modules in
   transaction_snakrs/test library for testing these rules with
   constructing actual transactions and applying them to a ledger. *)
let%test_module "Test account timing." =
  ( module struct
    (* Test that the timed account generator only generates accounts that
       are completely vested before the largest possible slot, (2^32)-1. *)
    let%test_unit "Test fine-tuning of the account generation." =
      Quickcheck.test Account.gen_timed ~f:(fun account ->
          [%test_eq: Balance.t option] (Some Balance.zero)
            ( match account.timing with
            | Untimed ->
                None
            | Timed
                { initial_minimum_balance
                ; cliff_time
                ; cliff_amount
                ; vesting_period
                ; vesting_increment
                } ->
                let global_slot = Global_slot.max_value in
                Option.some
                @@ Account.min_balance_at_slot ~global_slot ~cliff_time
                     ~cliff_amount ~vesting_period ~vesting_increment
                     ~initial_minimum_balance ) )

    let%test_unit "Untimed accounts succeed if they have enough funds." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen in
        let%bind amount =
          Amount.(gen_incl zero (Balance.to_amount account.balance))
        in
        let%map slot = Global_slot.gen in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result] (Ok Account.Timing.Poly.Untimed)
            (validate_timing ~account ~txn_amount ~txn_global_slot) )

    let%test_unit "All accounts fail if funds are insufficient." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account =
          let open Quickcheck.Generator in
          union [ Account.gen; Account.gen_timed ]
          |> filter ~f:(fun a -> Balance.(a.balance < max_int))
        in
        let min_amount =
          Amount.(Balance.to_amount account.balance + of_nanomina_int_exn 1)
          |> Option.value ~default:Amount.max_int
        in
        let%bind amount = Amount.gen_incl min_amount Amount.max_int in
        let%map slot = Global_slot.gen in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result]
            ( Or_error.errorf
                !"For timed account, the requested transaction for amount \
                  %{sexp: Amount.t} at global slot %{sexp: Global_slot.t}, the \
                  balance %{sexp: Balance.t} is insufficient"
                txn_amount txn_global_slot account.balance
            |> Result.map_error ~f:(Error.tag ~tag:nsf_tag) )
            (validate_timing ~account ~txn_amount ~txn_global_slot) )

    let%test_unit "Before cliff time balance above the minimum can be spent." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen_timed in
        let max_amount =
          let open Balance in
          account.balance - to_amount (init_min_bal account)
          |> Option.value_map ~default:Amount.zero ~f:to_amount
        in
        let%bind amount = Amount.(gen_incl zero max_amount) in
        let max_slot = Global_slot.(of_int (to_int (cliff_time account) - 1)) in
        let%map slot = Global_slot.(gen_incl zero max_slot) in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result]
            (validate_timing ~account ~txn_amount ~txn_global_slot)
            (Ok account.timing) )

    let%test_unit "Before the end of vesting, timing never changes." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen_timed in
        let available_amount =
          let open Balance in
          account.balance - to_amount (init_min_bal account)
          |> Option.value_map ~f:Balance.to_amount ~default:Amount.zero
        in
        let%bind amount = Amount.(gen_incl zero available_amount) in
        let final_slot =
          Global_slot.(
            sub (timing_final_vesting_slot account.timing) (of_int 1))
          |> Option.value ~default:Global_slot.zero
        in
        let%map slot = Global_slot.(gen_incl zero final_slot) in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result] (Ok account.timing)
            (validate_timing ~account ~txn_amount ~txn_global_slot) )

    let%test_unit "Account with zero minimum balance becomes untimed." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen_timed in
        let%bind amount =
          Amount.(gen_incl zero (Balance.to_amount account.balance))
        in
        let final_slot = timing_final_vesting_slot account.timing in
        let%map slot = Global_slot.(gen_incl final_slot max_value) in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result]
            (validate_timing ~account ~txn_amount ~txn_global_slot)
            (Ok Untimed) )

    let%test_unit "Timed accounts fail if minimum balance would be violated." =
      Quickcheck.test
        (let open Quickcheck.Generator.Let_syntax in
        let%bind account = Account.gen_timed in
        let available_amount =
          let open Balance in
          (let open Option.Let_syntax in
          let%bind avail = account.balance - to_amount (init_min_bal account) in
          Amount.(to_amount avail + of_nanomina_int_exn 1))
          |> Option.value ~default:Amount.zero
        in
        let%bind amount =
          Amount.(gen_incl available_amount (Balance.to_amount account.balance))
        in
        let%map slot =
          Global_slot.(
            gen_incl zero (of_int @@ (to_int (cliff_time account) - 1)))
        in
        (account, amount, slot))
        ~f:(fun (account, txn_amount, txn_global_slot) ->
          [%test_eq: txn_result]
            ( Or_error.errorf
                !"For timed account, the requested transaction for amount \
                  %{sexp: Amount.t} at global slot %{sexp: Global_slot.t}, \
                  applying the transaction would put the balance below the \
                  calculated minimum balance of %{sexp: Balance.t}"
                txn_amount txn_global_slot (init_min_bal account)
            |> Or_error.tag ~tag:min_balance_tag )
            (validate_timing ~account ~txn_amount ~txn_global_slot) )
  end )
