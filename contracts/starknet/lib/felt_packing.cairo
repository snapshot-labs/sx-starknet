%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.bitwise import bitwise_and, ALL_ONES
from starkware.cairo.common.math_cmp import is_le
from contracts.lib.pow2 import pow2

//
// @title Bits Manipulation
// @notice Manipulate the bits to be able to encode and decode felts within another felt, for more info refer to the README
//

// @notice Will return the number encoded at for a certain number of bits
// @dev This method can fail
// @param input: The felt from which it needs to be extracted from
// @param at: The position of the element that needs to be extracted, starts a 0
// @param number_of_bits: The size of the element that needs to be extracted
// @return response: The felt that was extracted at the position asked, on the number of bits asked
@view
func actual_get_element_at{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(input: felt, at: felt, number_of_bits: felt) -> (response: felt) {
    let (mask) = internal.generate_get_mask(at, number_of_bits);
    let (masked_response) = bitwise_and(mask, input);
    let (divider) = pow2(at);
    let response = masked_response / divider;
    return (response,);
}

// @notice Will return the a new felt with the felt encoded at a certain position on a certain number of bits
// @dev This method can fail
// @param input: The felt from which it needs to be included in
// @param at: The position of the element that needs to be added, starts a 0
// @param number_of_bits: The size of the element that needs to be added
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
@view
func actual_set_element_at{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(input: felt, at: felt, number_of_bits: felt, element: felt) -> (response: felt) {
    internal.assert_valid_felt(element, number_of_bits);
    let (mask) = internal.generate_set_mask(at, number_of_bits);
    let (masked_intermediate_response) = bitwise_and(mask, input);
    return internal.unsafe_set_element_at(masked_intermediate_response, at, element);
}

// @notice Will return the a new felt with the felt encoded at a certain position on a certain number of bits
//          Use with caution only when you are sure that the spot you are putting the new field element is full of zeros
//          It will basically skip the entire MASK part
// @dev This method can fail
// @param input: The felt from which it needs to be included in
// @param at: The position of the element that needs to be extracted, starts a 0
// @param number_of_bits: The size of the element that needs to be extracted
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
@view
func quick_set_element_at{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(input: felt, at: felt, number_of_bits: felt, element: felt) -> (response: felt) {
    internal.assert_valid_felt(element, number_of_bits);
    return internal.unsafe_set_element_at(input, at, element);
}

namespace internal {
    // @notice Will set the input at tjhe given position
    // @dev Cannot fail
    // @param position: The position of the element that needs to be set, starts a 0
    // @param element: The element that needs to be encoded
    // @return response: The new felt containing the encoded value a the given position on the given number of bits
    func unsafe_set_element_at{
        bitwise_ptr: BitwiseBuiltin*,
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
    }(input: felt, at: felt, element: felt) -> (response: felt) {
        let (multiplier) = pow2(at);
        let multiplied_element = element * multiplier;
        return (response=input + multiplied_element);
    }

    // @notice Will generate a bit mask to extract a felt within another felt
    // @dev Will fail if the position given would make it out of the 251 available bits
    // @param position: The position of the element that needs to be extracted, starts a 0
    // @param number_of_bits: The size of the element that needs to be extracted
    // @return mask: the "get" mask corresponding to the position and the number of bits
    func generate_get_mask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        position: felt, number_of_bits: felt
    ) -> (mask: felt) {
        return internal.generate_mask(position, number_of_bits);
    }

    // @notice Will generate a bit mask to be able to insert a felt within another felt
    // @dev Will fail if the position given would make it out of the 251 available bits
    // @param position: The position of the element that needs to be inserted, starts a 0
    // @param number_of_bits: the number of bits on which each element is encoded
    // @return mask: the "set" mask corresponding to the position and the number of bits
    func generate_set_mask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        position: felt, number_of_bits: felt
    ) -> (mask: felt) {
        let (intermediate_mask) = internal.generate_mask(position, number_of_bits);
        let mask = ALL_ONES - intermediate_mask;
        return (mask,);
    }

    // @notice Will generate the mask part that is common to set_mask and get_mask
    // @dev Will fail if the position given would make it out of the 251 available bits
    // @param position: The position of the element that needs to be inserted, starts a 0
    // @param number_of_bits: the number of bits on which each element is encoded
    // @return mask: the mask corresponding to the position and the number of bits
    func generate_mask{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        position: felt, number_of_bits: felt
    ) -> (mask: felt) {
        assert_within_range(position, number_of_bits);
        let (pow_big) = pow2(number_of_bits + position);
        let (pow_small) = pow2(position);
        let mask = (pow_big - 1) - (pow_small - 1);
        return (mask,);
    }

    // @notice Will check that the given element isn't to big to be stored
    // @dev Will fail if the felt is too big, which is relative to number_of_bits
    // @param element: the element that needs to be checked
    // @param number_of_bits: the number of bits on which each element is encoded
    func assert_valid_felt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        element: felt, number_of_bits: felt
    ) {
        let (max) = pow2(number_of_bits);
        let is_bigger = is_le(element, max - 1);
        with_attr error_message("Error felt too big") {
            assert is_bigger = TRUE;
        }
        return ();
    }
    // @notice Will check that the given position finumber_of_bitsts within the 251 bits available
    // @dev Will fail if the position is too big +
    // @param position: The position of the element, starts a 0
    // @param number_of_bits: the number of bits on which each element is encoded
    func assert_within_range{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        position: felt, number_of_bits: felt
    ) {
        let is_bigger = is_le(position + number_of_bits, 251);
        with_attr error_message("Error out of bound at: {position + number_of_bits}") {
            assert is_bigger = TRUE;
        }
        return ();
    }
}
