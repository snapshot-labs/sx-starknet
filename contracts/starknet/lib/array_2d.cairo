struct Immutable2DArray:
    member offsets_len : felt  # The length of the offsets array is the number of sub arrays in the 2d array
    member offsets : felt*  # offsets[i] is the index of elements where the ith array starts
    member elements_len : felt
    member elements : felt*  # elements stores all the values of each sub array in the 2d array
end

namespace Array2D:
    # Currently there is no way to pass struct types with pointers in calldata, so we must pass the 2d array as a flat array and then reconstruct the type.
    # The structure of the flat array that is passed should be as follows:
    # flat_array[0] = num_arrays
    # flat_array[1:1+num_arrays] = offsets
    # flat_array[1+num_arrays:] = elements
    func construct_array2d{range_check_ptr}(flat_array_len : felt, flat_array : felt*) -> (
        array2d : Immutable2DArray
    ):
        let offsets_len = flat_array[0]
        let offsets = &flat_array[1]
        let elements_len = flat_array_len - offsets_len - 1
        let elements = &flat_array[1 + offsets_len]
        let array2d = Immutable2DArray(offsets_len, offsets, elements_len, elements)
        return (array2d)
    end

    func get_sub_array{range_check_ptr}(array2d : Immutable2DArray, index : felt) -> (
        array_len : felt, array : felt*
    ):
        let offset = array2d.offsets[index]
        let array = &array2d.elements[offset]

        if index == array2d.offsets_len - 1:
            # If the index points to the final array in the 2d array, the length of the sub array is the length of the 2d array elements minus the offset of the final array
            tempvar array_len = array2d.elements_len - offset
        else:
            # Otherwise the length of the sub array is the offset of the next array minus the offset of the current array
            tempvar array_len = array2d.offsets[index + 1] - offset
        end
        return (array_len, array)
    end
end
