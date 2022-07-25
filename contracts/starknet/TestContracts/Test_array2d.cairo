%lang starknet
from starknet.lib.array2d import Immutable2DArray, construct_array2d, get_sub_array

@view
func test_array2d{range_check_ptr}(flat_array_len : felt, flat_array : felt*, index : felt) -> (
    array_len : felt, array : felt*
):
    alloc_locals
    let (array2d : Immutable2DArray) = construct_array2d(flat_array_len, flat_array)
    let (array_len, array) = get_sub_array(array2d, index)
    return (array_len, array)
end
