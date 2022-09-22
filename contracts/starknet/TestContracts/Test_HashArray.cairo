%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starknet.lib.hash_array import HashArray
@view
func test_hash_array{range_check_ptr, pedersen_ptr : HashBuiltin*}(
    array_len : felt, array : felt*
) -> (hash : felt):
    let (hash) = HashArray.hash_array(array_len, array)
    return (hash)
end
