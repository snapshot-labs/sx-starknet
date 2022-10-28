// SPDX-License-Identifier: MIT
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import unsigned_div_rem, assert_not_zero, assert_not_equal

from openzeppelin.token.erc20.IERC20 import IERC20

// TODO: events

struct Checkpoint {
    voting_weight: felt,
    timestamp: felt,
}

@storage_var
func Delegate_delegatee_store(account: felt) -> (delegatee: felt) {
}

@storage_var
func Delegate_checkpoints_length_store(account: felt) -> (len: felt) {
}

@storage_var
func Delegate_checkpoints_store(account: felt, index: felt) -> (checkpoint: Checkpoint) {
}

@storage_var
func Delegate_token_contract() -> (token_contract: felt) {
}

// Recursive binary search (O(log(n))
func find_closest_index{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    account: felt, low: felt, high: felt, timepoint: felt
) -> felt {
    let done = is_le(high, low);
    if (done == 1) {
        return high;
    } else {
        let (mid, _) = unsigned_div_rem(high + low, 2);  // Get the mid point
        let (checkpoint) = Delegate_checkpoints_store.read(account, mid);

        let is_lower_or_eq = is_le(checkpoint.timestamp, timepoint);
        if (is_lower_or_eq == 1) {
            return find_closest_index(account, mid + 1, high, timepoint);
        } else {
            return find_closest_index(account, low, mid, timepoint);
        }
    }
}

func get_closest_index{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    account: felt, timepoint: felt
) -> felt {
    let (high) = Delegate_checkpoints_length_store.read(account);

    if (high == 0) {
        return 0;
    } else {
        let low = 0;
        let index = find_closest_index(account, low, high - 1, timepoint);
        return index;
    }
}

func get_latest_checkpoint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    account: felt
) -> (checkpoint: Checkpoint) {
    let (index) = Delegate_checkpoints_length_store.read(account);
    if (index == 0) {
        tempvar latest_index = 0;
    } else {
        tempvar latest_index = index - 1;
    }
    let (checkpoint) = Delegate_checkpoints_store.read(account, latest_index);
    return (checkpoint=checkpoint);
}

func substract_checkpoint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt, amount: felt) -> (old_value: felt, new_value: felt) {
    alloc_locals;

    let (latest_checkpoint) = get_latest_checkpoint(account);
    let (now) = Delegate.now();
    let new_amount = latest_checkpoint.voting_weight - amount;
    let new_checkpoint = Checkpoint(new_amount, now); // TODO: check for underflow?
    let (index) = Delegate_checkpoints_length_store.read(account); // could optimize one read because of get_latest_cp

    Delegate_checkpoints_store.write(account, index, new_checkpoint);
    Delegate_checkpoints_length_store.write(account, index + 1);
    return (latest_checkpoint.voting_weight, new_amount);
}

func add_checkpoint{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt, amount: felt) -> (old_value: felt, new_value: felt) {
    alloc_locals;

    let (latest_checkpoint) = get_latest_checkpoint(account);
    let (now) = Delegate.now();
    let new_amount = latest_checkpoint.voting_weight + amount;
    let new_checkpoint = Checkpoint(new_amount, now);
    let (index) = Delegate_checkpoints_length_store.read(account);

    Delegate_checkpoints_store.write(account, index, new_checkpoint);
    Delegate_checkpoints_length_store.write(account, index + 1);
    return (latest_checkpoint.voting_weight, new_amount);
}

namespace Delegate {
    func _transferVotingUnits{syscall_ptr: felt*}(_from: felt, to: felt, amount: felt) {
        if (_from == 0) {
            // total supply?
        }
        if (to == 0) {
            // total supply?
        }
        _moveDelegateVotes(_from, to, amount);
    }

    func _moveDelegateVotes{syscall_ptr: felt*}(_from: felt, to: felt, amount: felt) {
        if (_from == to) {
            return ();
        }
        let amount_is_negative = is_le(amount, 0);
        if (amount_is_megative == 1) {
            return ();
        }

        if (_from == 0) {
        } else {
            let (old_value, new_value) = substract_checkpoint(_from, amount);
            // event
        }
        if (to == 0) {
        } else {
            let (old_value, new_value) = add_checkpoint(to, amount);
            // event
        }
    }

    func now{syscall_ptr: felt*}() -> (timepoint: felt) {
        let (timepoint) = get_block_timestamp();
        return (timepoint=timepoint);
    }

    func get_votes{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt) -> (votingWeight: felt) {
        let (len) = Delegate_checkpoints_length_store.read(account);
        let (checkpoint) = Delegate_checkpoints_store.read(account, len);

        return (votingWeight=checkpoint.voting_weight);
    }

    func get_past_votes{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt, timepoint: felt) -> (votingWeight: felt) {
        let (now) = Delegate.now();
        let is_valid = is_le(timepoint, now);
        with_attr error_message("Delegate: timepoint is too high") {
            assert is_valid = 1;
        }

        let index = get_closest_index(account, timepoint);
        let (checkpoint) = Delegate_checkpoints_store.read(account, index);
        return (votingWeight=checkpoint.voting_weight);
    }

    func delegate{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(delegatee: felt) {
        alloc_locals;

        let (user) = get_caller_address();  // check 0?
        let (old_delegatee) = Delegate_delegatee_store.read(user);
        if (old_delegatee == delegatee) {
            return ();
        }

        let (token_contract) = Delegate_token_contract.read();
        let (u256_balance) = IERC20.balanceOf(token_contract, user);
        let balance = u256_balance.low;  // TODO: use high part also
        let (timestamp) = get_block_timestamp();
        let (delegatee_old_cp) = get_latest_checkpoint(delegatee);
        let delegatee_new_cp = Checkpoint(delegatee_old_cp.voting_weight + balance, timestamp);
        let (new_index) = Delegate_checkpoints_length_store.read(delegatee);
        Delegate_checkpoints_store.write(delegatee, new_index, delegatee_new_cp);
        Delegate_checkpoints_length_store.write(delegatee, new_index + 1);

        let (prev_delegatee_old_cp) = get_latest_checkpoint(old_delegatee);
        let prev_delegatee_new_cp = Checkpoint(prev_delegatee_old_cp.voting_weight - balance, timestamp);
        let (new_index) = Delegate_checkpoints_length_store.read(old_delegatee);
        Delegate_checkpoints_store.write(old_delegatee, new_index, prev_delegatee_new_cp);
        Delegate_checkpoints_length_store.write(old_delegatee, new_index + 1);
        Delegate_delegatee_store.write(user, delegatee);
        return ();
    }

    func delegates{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(account: felt) -> (delegatee: felt) {
        let (delegatee) = Delegate_delegatee_store.read(account);
        return (delegatee=delegatee);
    }
}
