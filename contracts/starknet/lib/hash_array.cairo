from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.alloc import alloc

# Internal utility function to hash felt arrays.
# Dev note: starkware.py and starknet.js methods for hashing an array append the length of the array to the end before hashing.
# This is why we replicate that here.
func hash_array{pedersen_ptr : HashBuiltin*}(array_len : felt, array : felt*) -> (hash : felt):
    # Hash the array
    let (hash_state_ptr) = hash_init()
    let (hash_state_ptr) = hash_update{hash_ptr=pedersen_ptr}(hash_state_ptr, array, array_len)

    # Append the length of the array to itself as the offchain version of the hash works this way
    let (suffix : felt*) = alloc()
    assert suffix[0] = array_len

    let (hash_state_ptr) = hash_update{hash_ptr=pedersen_ptr}(hash_state_ptr, suffix, 1)

    return (hash_state_ptr.current_hash)
end
