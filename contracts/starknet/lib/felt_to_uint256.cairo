from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.uint256 import Uint256

const MASK_LOW = 2 ** 128 - 1
const MASK_HIGH = 2 ** 251 - 2 ** 128

const SHIFT_8 = 2 ** 8
const SHIFT_120 = 2 ** 120

# Convert a felt to 2 128 bit words returned as a uint256.
func felt_to_uint256{bitwise_ptr : BitwiseBuiltin*, range_check_ptr}(value : felt) -> (
    uint256 : Uint256
):
    let (low) = bitwise_and(value, MASK_LOW)

    let (t1) = bitwise_and(value, MASK_HIGH)
    let (t1, _) = unsigned_div_rem(t1, SHIFT_120)
    let (high, _) = unsigned_div_rem(t1, SHIFT_8)

    return (Uint256(low=low, high=high))
end
