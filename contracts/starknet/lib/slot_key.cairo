from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.keccak import unsafe_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import split_felt

namespace SlotKey {
    // Returns the EVM slot key for mappings (key can be any value type)
    // UNSAFE: This is not safe to use in production code due to unsafe keccak - waiting for safe version
    func get_slot_key{range_check_ptr}(slot_index: felt, mapping_key: felt) -> (slot_key: Uint256) {
        alloc_locals;
        let (encoded_array: felt*) = alloc();
        let (slot_index_high, slot_index_low) = split_felt(slot_index);
        let (mapping_key_high, mapping_key_low) = split_felt(mapping_key);
        encoded_array[0] = mapping_key_high;
        encoded_array[1] = mapping_key_low;
        encoded_array[2] = slot_index_high;
        encoded_array[3] = slot_index_low;
        let (low, high) = unsafe_keccak(encoded_array, 64);
        let slot_key = Uint256(low=low, high=high);
        return (slot_key,);
    }
}
