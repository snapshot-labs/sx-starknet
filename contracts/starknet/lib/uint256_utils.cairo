// SPDX-License-Identifier: MIT

from starkware.cairo.common.uint256 import Uint256, uint256_check

namespace Uint256Utils {
    // Wrapper function to check if `uint256` is a valid `Uint256`.
    // Wrapper is needed to have a proper error message.
    func assert_valid_uint256{range_check_ptr}(uint256: Uint256) {
        with_attr error_message("Uint256Utils: Invalid Uint256") {
            uint256_check(uint256);
        }
        return ();
    }
}
