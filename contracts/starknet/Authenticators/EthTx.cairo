%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import call_contract
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import assert_not_equal
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.hash_array import HashArray
from contracts.starknet.lib.execute import execute

// Address of the StarkNet Commit L1 contract which acts as the origin address of the messages sent to this contract.
@storage_var
func starknet_commit_address_store() -> (res: felt) {
}

// Mapping between a commit and the L1 address of the sender.
@storage_var
func commit_store(hash: felt) -> (address: Address) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    starknet_commit_address: felt
) {
    starknet_commit_address_store.write(value=starknet_commit_address);
    return ();
}

// Receives hash from StarkNet commit contract and stores it in state.
@l1_handler
func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    from_address: felt, sender: Address, hash: felt
) {
    // Check L1 message origin is equal to the StarkNet commit address.
    let (origin) = starknet_commit_address_store.read();
    with_attr error_message("Invalid message origin address") {
        assert from_address = origin;
    }
    // Note: If the same hash is committed twice by the same sender, then the mapping will be overwritten but with the same value as before.
    commit_store.write(hash, sender);
    return ();
}

@external
func authenticate{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
    target: felt, function_selector: felt, calldata_len: felt, calldata: felt*
) {
    alloc_locals;
    // Cast arguments to single array
    let (input_array: felt*) = alloc();
    assert input_array[0] = target;
    assert input_array[1] = function_selector;
    memcpy(input_array + 2, calldata, calldata_len);
    // Hash array
    let (hash) = HashArray.hash_array(calldata_len + 2, input_array);
    // Check that the hash has been received by the contract from the StarkNet Commit contract
    let (address) = commit_store.read(hash);
    with_attr error_message("Hash not yet committed or already executed") {
        assert_not_equal(address.value, 0);
    }
    // The sender of the commit on L1 must be the same as the voter/proposer L1 address in the calldata.
    with_attr error_message("Commit made by invalid L1 address") {
        assert calldata[0] = address.value;
    }
    // Clear the hash from the contract by writing the zero address to the mapping.
    commit_store.write(hash, Address(0));
    // Execute the function call with calldata supplied.
    execute(target, function_selector, calldata_len, calldata);
    return ();
}
