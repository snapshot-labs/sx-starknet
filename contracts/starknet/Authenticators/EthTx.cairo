// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from contracts.starknet.lib.array_utils import ArrayUtils
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eth_tx import EthTx

//
// @title Ethereum Transaction Authenticator
// @author SnapshotLabs
// @notice Contract to allow authentication of Snapshot X users via an Ethereum transaction
//

// @dev Constructor
// @param starknet_commit_address Address of the StarkNet Commit Ethereum contract
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    starknet_commit_address: felt
) {
    EthTx.initializer(starknet_commit_address);
    return ();
}

// @dev Authentication of an action (vote or propose) via an Ethereum transaction
// @param target Address of the space contract
// @param function_selector Function selector of the action
// @param calldata Calldata array required for the action
@external
func authenticate{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    target: felt, function_selector: felt, calldata_len: felt, calldata: felt*
) {
    alloc_locals;
    // Cast arguments to single array and hash them
    let (input_array: felt*) = alloc();
    assert input_array[0] = target;
    assert input_array[1] = function_selector;
    memcpy(input_array + 2, calldata, calldata_len);
    let (hash) = ArrayUtils.hash(calldata_len + 2, input_array);

    // Checks that hash matches a commit and that the commit was created by the correct address
    let address = calldata[0];
    EthTx.consume_commit(hash, address);

    // Execute the function call with calldata supplied.
    execute(target, function_selector, calldata_len, calldata);
    return ();
}

// @dev L1 handler that receives hash from StarkNet Commit contract and stores it in state
// @param from_address Origin contract address of the L1 message
// @param sender_address Address of user that initiated the L1 message transaction
// @param hash The commit payload
@l1_handler
func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    from_address: felt, sender_address: felt, hash: felt
) {
    EthTx.commit(from_address, sender_address, hash);
    return ();
}
