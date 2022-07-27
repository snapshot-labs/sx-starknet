from starkware.cairo.common.math import split_felt
from starkware.cairo.common.uint256 import Uint256

# Converts a felt to two 128 bit words returned as a Uint256.
func felt_to_uint256{range_check_ptr}(value : felt) -> (uint256 : Uint256):
    let (high, low) = split_felt(value)
    return (Uint256(low=low, high=high))
end
