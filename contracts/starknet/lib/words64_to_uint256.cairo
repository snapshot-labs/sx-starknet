from starkware.cairo.common.uint256 import Uint256

const SHIFT_64 = 2 ** 64

# Convert a 4 words of 64 bits per felt to a Uint256 (128 bits per felt)
# Word 1 is the most significant word and word 4 is the least significant word
func words64_to_uint256{range_check_ptr}(
    word1 : felt, word2 : felt, word3 : felt, word4 : felt
) -> (uint256 : Uint256):
    let word1_shifted = word1 * SHIFT_64
    let word3_shifted = word3 * SHIFT_64
    return (Uint256(low=word3_shifted + word4, high=word1_shifted + word2))
end
