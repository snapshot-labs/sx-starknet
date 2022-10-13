// SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address

from contracts.starknet.lib.execute import execute

//
// @title StarkNet Transaction Authenticator
// @author SnapshotLabs
// @notice Contract to allow authentication of Snapshot X users via a StarkNet transaction
//

// @dev Authentication of an action (vote or propose) via a StarkNet transaction
// @param target Address of the space contract
// @param function_selector Function selector of the action
// @param calldata Calldata array required for the action
@external
func authenticate{syscall_ptr: felt*, range_check_ptr}(
    target: felt, function_selector: felt, calldata_len: felt, calldata: felt*
) -> () {
    let (caller_address) = get_caller_address();
    with_attr error_message("Incorrect caller") {
        assert caller_address = calldata[0];
    }
    execute(target, function_selector, calldata_len, calldata);
    return ();
}
