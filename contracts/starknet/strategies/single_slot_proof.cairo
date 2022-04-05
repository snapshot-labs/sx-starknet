%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.math import unsigned_div_rem, assert_nn_le
from contracts.starknet.fossil.contracts.starknet.types import StorageSlot

# FactRegistry simplified interface
@contract_interface
namespace IFactsRegistry:
    func get_storage_uint(
            block : felt, account_160 : felt, slot : StorageSlot, proof_sizes_bytes_len : felt,
            proof_sizes_bytes : felt*, proof_sizes_words_len : felt, proof_sizes_words : felt*,
            proofs_concat_len : felt, proofs_concat : felt*) -> (res : Uint256):
    end
end

# Address of the fact registry. This is an immutable value that can be set at contract deployment only.
@storage_var
func fact_registry_store() -> (res : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        fact_registry : felt):
    fact_registry_store.write(value=fact_registry)
    return ()
end

@view
func get_voting_power{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*}(
        block : felt, account_160 : felt, params_len : felt, params : felt*) -> (
        voting_power : Uint256):
    alloc_locals
    let (local fact_registry_addr) = fact_registry_store.read()

    # Decoding voting strategy parameters
    let (slot, proof_sizes_bytes_len, proof_sizes_bytes, proof_sizes_words_len, proof_sizes_words,
        proofs_concat_len, proofs_concat) = decode_param_array(params_len, params)

    # Calling Fossil Fact Registry to verify the storage proof of the slot value
    let (voting_power) = IFactsRegistry.get_storage_uint(
        fact_registry_addr,
        block,
        account_160,
        slot,
        proof_sizes_bytes_len,
        proof_sizes_bytes,
        proof_sizes_words_len,
        proof_sizes_words,
        proofs_concat_len,
        proofs_concat)

    return (voting_power)
end

@view
func decode_param_array{range_check_ptr}(param_array_len : felt, param_array : felt*) -> (
        slot : StorageSlot, proof_sizes_bytes_len : felt, proof_sizes_bytes : felt*,
        proof_sizes_words_len : felt, proof_sizes_words : felt*, proofs_concat_len : felt,
        proofs_concat : felt*):
    assert_nn_le(4, param_array_len)
    let slot : StorageSlot = StorageSlot(
        param_array[0], param_array[1], param_array[2], param_array[3])
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
        proofs_concat)
end
