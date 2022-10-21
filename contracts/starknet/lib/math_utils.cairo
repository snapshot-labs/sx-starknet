// SPDX-License-Identifier: MIT

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, split_felt, assert_nn_le
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.uint256 import Uint256, uint256_check

const MAX_32 = 2 ** 32 - 1;

const SHIFT_32 = 2 ** 32;
const SHIFT_64 = 2 ** 64;
const SHIFT_96 = 2 ** 96;

const MASK_4 = 2 ** 32 - 1;
const MASK_3 = 2 ** 64 - 2 ** 32;
const MASK_2 = 2 ** 96 - 2 ** 64;
const MASK_1 = 2 ** 128 - 2 ** 96;

//
// @title Math Utilities Library
// @author SnapshotLabs
// @notice A library containing various math utilities
//

namespace MathUtils {
    // @dev Converts 4 words of 64 bits each to a Uint256
    // @param word1 1st word (most significant word)
    // @param word2 2nd word
    // @param word3 3rd word
    // @param word4 4th word (least significant word)
    // @return uint256 The Uint256
    func words_to_uint256{range_check_ptr}(word1: felt, word2: felt, word3: felt, word4: felt) -> (
        uint256: Uint256
    ) {
        let word1_shifted = word1 * SHIFT_64;
        let word3_shifted = word3 * SHIFT_64;
        let result = Uint256(low=word3_shifted + word4, high=word1_shifted + word2);
        MathUtils.assert_valid_uint256(result);
        return (result,);
    }

    // @dev Converts a felt to a Uint256
    // @param value The felt
    // @return uint256 The Uint256
    func felt_to_uint256{range_check_ptr}(value: felt) -> (uint256: Uint256) {
        let (high, low) = split_felt(value);
        return (Uint256(low=low, high=high),);
    }

    // @dev Packs 4 32 bit numbers into a single felt
    // @param num1 1st number
    // @param num2 2nd number
    // @param num3 3rd number
    // @param num4 4th number
    // @return packed_felt The packed felt
    func pack_4_32_bit{range_check_ptr}(num1: felt, num2: felt, num3: felt, num4: felt) -> (
        packed_felt: felt
    ) {
        with_attr error_message("MathUtils: number too big to be packed") {
            assert_nn_le(num1, MAX_32);
            assert_nn_le(num2, MAX_32);
            assert_nn_le(num3, MAX_32);
            assert_nn_le(num4, MAX_32);
        }
        let packed_felt = num4 + num3 * SHIFT_32 + num2 * SHIFT_64 + num1 * SHIFT_96;
        return (packed_felt,);
    }

    // @dev Unpacks a felt into 4 32 bit numbers
    // @param packed_felt The packed felt
    // @return num1 1st number
    // @return num2 2nd number
    // @return num3 3rd number
    // @return num4 4th number
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

    // @dev Asserts that a uint256 is valid
    // @param uint256 The Uint256
    func assert_valid_uint256{range_check_ptr}(uint256: Uint256) {
        with_attr error_message("MathUtils: Invalid Uint256") {
            uint256_check(uint256);
        }
        return ();
    }
}
