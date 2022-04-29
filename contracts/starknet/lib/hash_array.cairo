from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_state import hash_init, hash_update

# Internal utility function to hash felt arrays.
# Dev note: starkware.py and starknet.js methods for hashing an array append the length of the array to the end before hashing.
# So if you wish to compare `hash_pedersen` to the off-chain hashing methods, make sure you append the length of the array before
# feeding it to `hash_pedersen`!
func hash_array{pedersen_ptr : HashBuiltin*}(array_len : felt, array : felt*) -> (hash : felt):
    # Appending the length of the array to itself as the offchain version of the hash works this way
    assert array[array_len] = array_len
    let (hash_state_ptr) = hash_init()
    let (hash_state_ptr) = hash_update{hash_ptr=pedersen_ptr}(hash_state_ptr, array, array_len + 1)
    return (hash_state_ptr.current_hash)
end
