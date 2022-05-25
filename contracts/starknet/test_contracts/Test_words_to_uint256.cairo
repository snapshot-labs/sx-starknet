%lang starknet
from starkware.cairo.common.uint256 import Uint256
from starknet.lib.words_to_uint256 import words_to_uint256

@view
func test_words_to_uint256{range_check_ptr}(
    word1 : felt, word2 : felt, word3 : felt, word4 : felt
) -> (uint256 : Uint256):
    let (uint256) = words_to_uint256(word1, word2, word3, word4)
    return (uint256)
end
