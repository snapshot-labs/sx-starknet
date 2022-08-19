%lang starknet
from contracts.starknet.lib.felt_utils import FeltUtils
from contracts.starknet.lib.hash_array import HashArray
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_uint256s_bigend,
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_builtins import HashBuiltin

namespace EthSigUtils:
    # Adds a 2 bytes (16 bits) `prefix` to a 16 bytes (128 bits) `value`.
    func add_prefix128{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
        value : felt, prefix : felt
    ) -> (result : felt, carry):
        # Shift the prefix by 128 bits
        let shifted_prefix = prefix * 2 ** 128
        # `with_prefix` is now 18 bytes long
        let with_prefix = shifted_prefix + value
        # Create 2 bytes mask
        let overflow_mask = 2 ** 16 - 1
        # Extract the last two bytes of `with_prefix`
        let (carry) = bitwise_and(with_prefix, overflow_mask)
        # Compute the new number, right shift by 16
        let result = (with_prefix - carry) / 2 ** 16
        return (result, carry)
    end

    # Concatenates a 2 bytes long `prefix` and `input` to `output`.
    # `input_len` is the number of `Uint256` in `input`.
    func prepend_prefix_2bytes{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
        prefix : felt, output : Uint256*, input_len : felt, input : Uint256*
    ):
        if input_len == 0:
            # Done, simlpy store the prefix in the `.high` part of the last Uint256, and
            # make sure we left shift it by 28 (32 - 4)
            assert output[0] = Uint256(0, prefix * 16 ** 28)
            return ()
        else:
            let num = input[0]

            let (w1, high_carry) = add_prefix128(num.high, prefix)
            let (w0, low_carry) = add_prefix128(num.low, high_carry)

            let res = Uint256(w0, w1)
            assert output[0] = res

            # Recurse, using the `low_carry` as `prefix`
            prepend_prefix_2bytes(low_carry, &output[1], input_len - 1, &input[1])
            return ()
        end
    end

    # Computes the `keccak256` hash from an array of `Uint256`. Does NOT call `finalize_keccak`,
    # so the caller needs to make she calls `finalize_keccak` on the `keccak_ptr` once she's done
    # with it.
    func get_keccak_hash{range_check_ptr, bitwise_ptr : BitwiseBuiltin*, keccak_ptr : felt*}(
        uint256_words_len : felt, uint256_words : Uint256*
    ) -> (hash : Uint256):
        let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words)

        return (hash)
    end

    # Returns the number of digits needed to represent `num` in hexadecimal.
    # Similar to doing `len(hex(num)[2:])` in Python.
    # E.g.:
    # - `0x123` will return `3`
    # - `0x1` will return `1`
    # - `0xa3b1d4` will return `6`
    # Notice: Will not work for `0x0` (will return `0` for `0x0` instead of `1`).
    func get_base16_len{range_check_ptr}(num : Uint256) -> (res : felt):
        let (is_eq) = uint256_eq(num, Uint256(0, 0))
        if is_eq == 1:
            return (0)
        else:
            # Divide by 16
            let (divided, _) = uint256_unsigned_div_rem(num, Uint256(16, 0))

            let (res_len) = get_base16_len(divided)
            return (res_len + 1)
        end
    end

    # Computes `base ** exp` where `base` and `exp` are both `felts` and returns the result as a `Uint256`.
    func u256_pow{range_check_ptr}(base : felt, exp : felt) -> (res : Uint256):
        alloc_locals

        if exp == 0:
            # Any number to the power of 0 is 1
            return (Uint256(1, 0))
        else:
            # Compute `base ** exp - 1`
            let (recursion) = u256_pow(base, exp - 1)

            let (uint256_base) = FeltUtils.felt_to_uint256(base)

            # Multiply the result by `base`
            let (res, overflow) = uint256_mul(recursion, uint256_base)

            with_attr error_message("Overflow happened"):
                let (no_overflow) = uint256_eq(overflow, Uint256(0, 0))
                assert no_overflow = 1
            end

            return (res)
        end
    end

    # Right pads `num` with `0` to make it 32 bytes long.
    # E.g:
    # - right_pad(0x1)  -> (0x0100000000000000000000000000000000000000000000000000000000000000)
    # - right_pad(0xaa) -> (0xaa00000000000000000000000000000000000000000000000000000000000000)
    func pad_right{range_check_ptr}(num : Uint256) -> (res : Uint256):
        let (len_base16) = get_base16_len(num)

        let (_, rem) = unsigned_div_rem(len_base16, 2)
        if rem == 1:
            # Odd-length: add one (a byte is two characters long)
            tempvar len_base16 = len_base16 + 1
        else:
            tempvar len_base16 = len_base16
        end

        let base = 16
        let exp = 64 - len_base16
        let (power_16) = u256_pow(base, exp)

        # Left shift
        let (low, high) = uint256_mul(num, power_16)

        with_attr error_message("overflow?"):
            assert high.low = 0
            assert high.high = 0
        end

        return (low)
    end

    func keccak_ints_sequence{range_check_ptr, bitwise_ptr : BitwiseBuiltin*, keccak_ptr : felt*}(
        nb_bytes : felt, sequence_len : felt, sequence : felt*
    ) -> (res : Uint256):
        return keccak_bigend(inputs=sequence, n_bytes=nb_bytes)
    end

    func get_padded_hash{range_check_ptr, pedersen_ptr : HashBuiltin*}(
        input_len : felt, input : felt*
    ) -> (res : Uint256):
        alloc_locals

        let (hash) = HashArray.hash_array(input_len, input)
        let (hash_u256) = FeltUtils.felt_to_uint256(hash)
        let (padded_hash) = pad_right(hash_u256)

        return (res=padded_hash)
    end
end
