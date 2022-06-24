from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.uint256 import Uint256

# Convert a felt to 2 128 bit words returned as a uint256.
func felt_to_uint256{range_check_ptr}(value : felt) -> (uint256 : Uint256):
    let (high, low) = split_felt(value)
    return (Uint256(low=low, high=high))
end
