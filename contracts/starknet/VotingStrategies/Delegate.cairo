// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.starknet.lib.delegate import Delegate, Delegate_token_contract

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_contract: felt
) {
    Delegate_token_contract.write(token_contract);
    return ();
}

@view
func now{syscall_ptr: felt*}() -> (timepoint: felt) {
    let (timepoint) = Delegate.now();
    return (timepoint=timepoint);
}


@view
func getVotes{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt) -> (votingWeight: felt) {
    let (voting_weight) = Delegate.get_votes(account);
    return (votingWeight=voting_weight);
}

@view
func getPastVotes{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt, timepoint: felt) -> (votingWeight: felt) {
    let (voting_weight) = Delegate.get_past_votes(account, timepoint);
    return (votingWeight=voting_weight);
}

@external
func delegate{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(delegatee: felt) {
    Delegate.delegate(delegatee);
    return ();
}

@view
func delegates{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt) -> (delegatee: felt) {
    let (delegatee) = Delegate.delegates(account);
    return (delegatee=delegatee);
}
