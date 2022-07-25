%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_nn_le

from contracts.starknet.fossil.contracts.starknet.types import StorageSlot
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.slot_key import get_slot_key
from contracts.starknet.lib.words import words_to_uint256
from contracts.starknet.lib.timestamp import get_eth_block_number, l1_headers_store

# FactRegistry simplified interface
@contract_interface
namespace IFactsRegistry:
    func get_storage_uint(
        block : felt,
        account_160 : felt,
        slot : StorageSlot,
        proof_sizes_bytes_len : felt,
        proof_sizes_bytes : felt*,
        proof_sizes_words_len : felt,
        proof_sizes_words : felt*,
        proofs_concat_len : felt,
        proofs_concat : felt*,
    ) -> (res : Uint256):
    end
end

# Address of the fact registry. This is an immutable value that can be set at contract deployment only.
@storage_var
func fact_registry_store() -> (res : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    fact_registry_address : felt, l1_headers_store_address : felt
):
    fact_registry_store.write(value=fact_registry_address)
    l1_headers_store.write(value=l1_headers_store_address)
    return ()
end

@view
func get_voting_power{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(
    timestamp : felt,
    voter_address : Address,
    params_len : felt,
    params : felt*,
    user_params_len : felt,
    user_params : felt*,
) -> (voting_power : Uint256):
    alloc_locals

    let (fact_registry_addr) = fact_registry_store.read()

    let (eth_block_number) = get_eth_block_number(timestamp)
    let eth_block_number = eth_block_number - 1  # temp shift - waiting for Fossil fix

    # Decoding voting strategy parameters
    let (
        slot,
        proof_sizes_bytes_len,
        proof_sizes_bytes,
        proof_sizes_words_len,
        proof_sizes_words,
        proofs_concat_len,
        proofs_concat,
    ) = decode_param_array(user_params_len, user_params)

    # Checking that the parameters array is valid and then extracting the individual parameters
    # For the single slot proof strategy, the parameters array is length 2 where the first element is the
    # contract address where the desired slot resides, and the section element is the index of the slot in that contract.
    assert params_len = 2
    let contract_address = params[0]
    let slot_index = params[1]

    # Checking slot proof is for the correct slot
    let (valid_slot) = get_slot_key(slot_index, voter_address.value)
    let (slot_uint256) = words_to_uint256(slot.word_1, slot.word_2, slot.word_3, slot.word_4)
    with_attr error_message("Invalid slot proof provided"):
        assert valid_slot = slot_uint256
    end

    # Calling Fossil Fact Registry to verify the storage proof of the slot value

    let (voting_power) = IFactsRegistry.get_storage_uint(
        fact_registry_addr,
        eth_block_number,
        contract_address,
        slot,
        proof_sizes_bytes_len,
        proof_sizes_bytes,
        proof_sizes_words_len,
        proof_sizes_words,
        proofs_concat_len,
        proofs_concat,
    )

    # If any part of the voting strategy calculation is invalid, the voting power returned should be zero
    return (voting_power)
end

@view
func decode_param_array{range_check_ptr}(param_array_len : felt, param_array : felt*) -> (
    slot : StorageSlot,
    proof_sizes_bytes_len : felt,
    proof_sizes_bytes : felt*,
    proof_sizes_words_len : felt,
    proof_sizes_words : felt*,
    proofs_concat_len : felt,
    proofs_concat : felt*,
):
    assert_nn_le(5, param_array_len)
    let slot : StorageSlot = StorageSlot(
        param_array[0], param_array[1], param_array[2], param_array[3]
    )
    let num_nodes = param_array[4]
    let proof_sizes_bytes_len = num_nodes
    let proof_sizes_bytes = param_array + 5
    let proof_sizes_words_len = num_nodes
    let proof_sizes_words = param_array + 5 + num_nodes
    let proofs_concat = param_array + 5 + 2 * num_nodes
    let proofs_concat_len = param_array_len - 5 - 2 * num_nodes
    # Could add check by summing proof_sizes_words array and checking that it is equal to proofs_concat_len
    # However this seems like unnecessary computation to do on-chain (proofs will fail if invalid params are sent anyway)
    return (
        slot,
        proof_sizes_bytes_len,
        proof_sizes_bytes,
        proof_sizes_words_len,
        proof_sizes_words,
        proofs_concat_len,
        proofs_concat,
    )
end
