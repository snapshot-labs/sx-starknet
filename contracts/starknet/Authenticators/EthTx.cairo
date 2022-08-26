%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from contracts.starknet.lib.hash_array import HashArray
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eth_tx import EthTx

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    starknet_commit_address : felt
):
    EthTx.initializer(starknet_commit_address)
    return ()
end

@external
func authenticate{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}(
    target : felt, function_selector : felt, calldata_len : felt, calldata : felt*
):
    alloc_locals
    # Cast arguments to single array and hash them
    let (input_array : felt*) = alloc()
    assert input_array[0] = target
    assert input_array[1] = function_selector
    memcpy(input_array + 2, calldata, calldata_len)
    let (hash) = HashArray.hash_array(calldata_len + 2, input_array)

    # Checks that hash maches a commit and that the commit was created by the correct address
    let address = calldata[0]
    EthTx.check_commit(hash, address)

    # Execute the function call with calldata supplied.
    execute(target, function_selector, calldata_len, calldata)
    return ()
end

# Receives hash from StarkNet commit contract and stores it in state.
@l1_handler
func commit{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    from_address : felt, sender : felt, hash : felt
):
    EthTx.commit(from_address, sender, hash)
    return ()
end
