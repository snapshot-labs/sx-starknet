%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_block_timestamp
from contracts.starknet.lib.felt_packing import quick_set_element_at, actual_get_element_at

@view
func test_pack_felt{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(num1: felt, num2: felt, num3: felt, num4: felt) -> (packed: felt) {
    let (packed) = quick_set_element_at(0, 32 * 0, 32, num1);
    let (packed) = quick_set_element_at(packed, 32 * 1, 32, num2);
    let (packed) = quick_set_element_at(packed, 32 * 2, 32, num3);
    let (packed) = quick_set_element_at(packed, 32 * 3, 32, num4);
    return (packed,);
}

@view
func test_unpack_felt{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(packed: felt) -> (num1: felt, num2: felt, num3: felt, num4: felt) {
    alloc_locals;
    let (num1) = actual_get_element_at(packed, 32 * 0, 32);
    let (num2) = actual_get_element_at(packed, 32 * 1, 32);
    let (num3) = actual_get_element_at(packed, 32 * 2, 32);
    let (num4) = actual_get_element_at(packed, 32 * 3, 32);
    return (num1, num2, num3, num4);
}
