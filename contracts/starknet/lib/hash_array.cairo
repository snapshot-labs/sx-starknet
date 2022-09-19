from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_state import hash_init, hash_update, hash_finalize

namespace HashArray {
    // Internal utility function to hash felt arrays.
    // Dev note: starkware.py and starknet.js methods for hashing an array append the length of the array to the end before hashing.
    // This is why we replicate that here.
    func hash_array{pedersen_ptr: HashBuiltin*}(array_len: felt, array: felt*) -> (hash: felt) {
        let (hash_state_ptr) = hash_init();
        let (hash_state_ptr) = hash_update{hash_ptr=pedersen_ptr}(hash_state_ptr, array, array_len);
        let (hash) = hash_finalize{hash_ptr=pedersen_ptr}(hash_state_ptr);
        return (hash,);
    }
}
