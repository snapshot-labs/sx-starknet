// SPDX-License-Identifier: MIT

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash_state import hash_init, hash_update, hash_finalize
from starkware.cairo.common.bool import TRUE, FALSE

struct Immutable2DArray {
    offsets_len: felt,  // The length of the offsets array is the number of sub arrays in the 2d array
    offsets: felt*,  // offsets[i] is the index of elements where the ith array starts
    elements_len: felt,
    elements: felt*,  // elements stores all the values of each sub array in the 2d array
}

namespace ArrayUtils {
    // Hash an array of felts
    func hash{pedersen_ptr: HashBuiltin*}(array_len: felt, array: felt*) -> (hash: felt) {
        let (hash_state_ptr) = hash_init();
        let (hash_state_ptr) = hash_update{hash_ptr=pedersen_ptr}(hash_state_ptr, array, array_len);
        let (hash) = hash_finalize{hash_ptr=pedersen_ptr}(hash_state_ptr);
        return (hash,);
    }

    // Tries to find `to_find` in `array`. Returns `TRUE` if it finds it, else returns `FALSE`.
    func find{}(to_find: felt, array_len: felt, array: felt*) -> (found: felt) {
        if (array_len == 0) {
            return (FALSE,);
        } else {
            if (to_find == array[0]) {
                return (TRUE,);
            } else {
                return find(to_find, array_len - 1, array + 1);
            }
        }
    }

    // Asserts that the array does not contain any duplicates.
    // O(N^2) as it loops over each element N times.
    func assert_no_duplicates{}(array_len: felt, array: felt*) {
        if (array_len == 0) {
            return ();
        } else {
            let to_find = array[0];

            // For each element in the array, try to find
            // this element in the rest of the array
            let (found) = find(to_find, array_len - 1, &array[1]);

            // If the element was found, we have found a duplicate.
            // Raise an error!
            with_attr error_message("ArrayUtils: Duplicate entry found") {
                assert found = FALSE;
            }

            assert_no_duplicates(array_len - 1, &array[1]);
            return ();
        }
    }

    // Construct an Immutable2D array from a flat encoding.
    // The structure of the flat array that is passed should be as follows:
    // flat_array[0] = num_arrays
    // flat_array[1:1+num_arrays] = offsets
    // flat_array[1+num_arrays:] = elements
    func construct_array2d{range_check_ptr}(flat_array_len: felt, flat_array: felt*) -> (
        array2d: Immutable2DArray
    ) {
        let offsets_len = flat_array[0];
        let offsets = &flat_array[1];
        let elements_len = flat_array_len - offsets_len - 1;
        let elements = &flat_array[1 + offsets_len];
        let array2d = Immutable2DArray(offsets_len, offsets, elements_len, elements);
        return (array2d,);
    }

    // Extracts sub array at the specified index from an Immutable2DArray
    func get_sub_array{range_check_ptr}(array2d: Immutable2DArray, index: felt) -> (
        array_len: felt, array: felt*
    ) {
        let offset = array2d.offsets[index];
        let array = &array2d.elements[offset];

        if (index == array2d.offsets_len - 1) {
            // If the index points to the final array in the 2d array, the length of the sub array is the length of the 2d array elements minus the offset of the final array
            tempvar array_len = array2d.elements_len - offset;
        } else {
            // Otherwise the length of the sub array is the offset of the next array minus the offset of the current array
            tempvar array_len = array2d.offsets[index + 1] - offset;
        }
        return (array_len, array);
    }
}
