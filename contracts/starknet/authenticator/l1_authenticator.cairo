%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import call_contract
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.hash_state import hash_init, hash_update
from starknet.lib.keccak_256_hash import Keccak256Hash
from starknet.lib.ints import IntsSequence
from starknet.lib.words import felt_to_words, Words
from starknet.fossil.contracts.starknet.lib.keccak import keccak256

# Address of the StarkNet Commit L1 contract which acts as the origin address of the message sent to this contract.
@storage_var
func starknet_commit_address_store() -> (res : felt):
end

# Mapping between a hash and a boolean on whether the hash is stored in the contract and has not yet been consumed.
@storage_var
func commit_store(hash : Keccak256Hash) -> (stored : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        starknet_commit_address : felt):
    starknet_commit_address_store.write(value=starknet_commit_address)
    return ()
end

# Receives hash from StarkNet commit contract and stores it in state.
@l1_handler
func commit_handler{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        from_address : felt, hash : Keccak256Hash):
    # Check L1 message origin
    let (origin) = starknet_commit_address_store.read()
    with_attr error_message("Invalid message origin address"):
        assert from_address = origin
    end
    # Check if hash is already stored
    let (stored) = commit_store.read(hash)
    with_attr error_message("Hash already committed"):
        assert stored = 0
    end
    commit_store.write(hash, 1)
    return ()
end

@external
func execute{
        syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*,
        bitwise_ptr : BitwiseBuiltin*}(
        target : felt, function_selector : felt, calldata_len : felt, calldata : felt*) -> (
        hash : felt):
    alloc_locals
    let (input_array : felt*) = alloc()
    assert input_array[0] = target
    assert input_array[1] = function_selector
    memcpy(input_array + 2, calldata, calldata_len)
    # Appending the length of the array to itself as the offchain version of the hash works this way
    assert input_array[calldata_len + 2] = calldata_len + 2
    let (hash_state_ptr) = hash_init()
    let (hash_state_ptr) = hash_update{hash_ptr=pedersen_ptr}(
        hash_state_ptr, input_array, calldata_len + 3)

    # Check that the hash has been received by the contract
    # let (stored) = commit_store.read(hash)
    # with_attr error_message("Hash not committed"):
    #     assert stored = 1
    # end

    # # Clear the hash from the contract
    # commit_store.write(hash, 0)

    # # Execute the function call with calldata supplied.
    # call_contract(
    #     contract_address=target,
    #     function_selector=function_selector,
    #     calldata_size=calldata_len,
    #     calldata=calldata)

    return (hash_state_ptr.current_hash)
end
