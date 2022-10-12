%lang starknet
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.starknet.lib.array_utils import ArrayUtils, Immutable2DArray

@view
func testArray2D{range_check_ptr}(flat_array_len: felt, flat_array: felt*, index: felt) -> (
    array_len: felt, array: felt*
) {
    alloc_locals;
    let (array2d: Immutable2DArray) = ArrayUtils.construct_array2d(flat_array_len, flat_array);
    let (array_len, array) = ArrayUtils.get_sub_array(array2d, index);
    return (array_len, array);
}

@view
func testHashArray{range_check_ptr, pedersen_ptr: HashBuiltin*}(array_len: felt, array: felt*) -> (
    hash: felt
) {
    let (hash) = ArrayUtils.hash(array_len, array);
    return (hash,);
}
