from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, split_felt, assert_nn_le
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.uint256 import Uint256
from contracts.starknet.lib.uint256_utils import Uint256Utils

const MAX_32 = 2 ** 32 - 1;

const SHIFT_32 = 2 ** 32;
const SHIFT_64 = 2 ** 64;
const SHIFT_96 = 2 ** 96;

const MASK_4 = 2 ** 32 - 1;
const MASK_3 = 2 ** 64 - 2 ** 32;
const MASK_2 = 2 ** 96 - 2 ** 64;
const MASK_1 = 2 ** 128 - 2 ** 96;

namespace FeltUtils {
    // Convert 4 words of 8 bytes each to a Uint256
    // Word 1 is the most significant word and word 4 is the least significant word
    func words_to_uint256{range_check_ptr}(word1: felt, word2: felt, word3: felt, word4: felt) -> (
        uint256: Uint256
    ) {
        let word1_shifted = word1 * SHIFT_64;
        let word3_shifted = word3 * SHIFT_64;
        let result = Uint256(low=word3_shifted + word4, high=word1_shifted + word2);

        Uint256Utils.assert_valid_uint256(result);

        return (result);
    }

    // Converts a felt to a Uint256.
    func felt_to_uint256{range_check_ptr}(value: felt) -> (uint256: Uint256) {
        let (high, low) = split_felt(value);
        return (Uint256(low=low, high=high),);
    }

    // Packs 4 32 bit numbers into a single felt
    func pack_4_32_bit{range_check_ptr}(num1: felt, num2: felt, num3: felt, num4: felt) -> (
        packed_felt: felt
    ) {
        with_attr error_message("FeltUtils: number too big to be packed") {
            assert_nn_le(num1, MAX_32);
            assert_nn_le(num2, MAX_32);
            assert_nn_le(num3, MAX_32);
            assert_nn_le(num4, MAX_32);
        }
        let packed_felt = num4 + num3 * SHIFT_32 + num2 * SHIFT_64 + num1 * SHIFT_96;
        return (packed_felt,);
    }

    // Unpacks a felt into 4 32 bit numbers
    func unpack_4_32_bit{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(packed_felt: felt) -> (
        num1: felt, num2: felt, num3: felt, num4: felt
    ) {
        let (num4) = bitwise_and(packed_felt, MASK_4);
        let (num3) = bitwise_and(packed_felt, MASK_3);
        let (num3, _) = unsigned_div_rem(num3, SHIFT_32);
        let (num2) = bitwise_and(packed_felt, MASK_2);
        let (num2, _) = unsigned_div_rem(num2, SHIFT_64);
        let (num1) = bitwise_and(packed_felt, MASK_1);
        let (num1, _) = unsigned_div_rem(num1, SHIFT_96);
        return (num1, num2, num3, num4);
    }
}
