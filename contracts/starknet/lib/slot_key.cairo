from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.keccak import unsafe_keccak
from starkware.cairo.common.uint256 import Uint256
from starknet.lib.felt_to_uint256 import felt_to_uint256

# Returns the EVM slot key for mappings (key can be any value type)
<<<<<<< HEAD
=======
# For more information, refer to the following repo:
# https://github.com/snapshot-labs/evm-slot-key-verification
>>>>>>> 52b2f15d36774198b2d33e8847367858a686421c
# UNSAFE: This is not safe to use in production code due to unsafe keccak - waiting for safe version
func get_slot_key{bitwise_ptr : BitwiseBuiltin*, range_check_ptr}(
    slot_index : felt, mapping_key : felt
) -> (slot_key : Uint256):
    alloc_locals
    let (encoded_array : felt*) = alloc()
    let (slot_index_uint256) = felt_to_uint256(slot_index)
    let (mapping_key_uint256) = felt_to_uint256(mapping_key)
    encoded_array[0] = mapping_key_uint256.high
    encoded_array[1] = mapping_key_uint256.low
    encoded_array[2] = slot_index_uint256.high
    encoded_array[3] = slot_index_uint256.low
<<<<<<< HEAD
    let (low, high) = unsafe_keccak(encoded_array, 64)
=======
    let (low, high) = unsafe_keccak(encoded_array, 16 * 4)
>>>>>>> 52b2f15d36774198b2d33e8847367858a686421c
    let slot_key = Uint256(low=low, high=high)
    return (slot_key)
end
