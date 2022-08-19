%lang starknet
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starknet.lib.felt_utils import FeltUtils, Words

@view
func test_words_to_uint256{range_check_ptr}(
    word1 : felt, word2 : felt, word3 : felt, word4 : felt
) -> (uint256 : Uint256):
    let (uint256) = FeltUtils.words_to_uint256(word1, word2, word3, word4)
    return (uint256)
end

@view
func test_felt_to_words{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(input : felt) -> (
    words : Words
):
    let (words) = FeltUtils.felt_to_words(input)
    return (words)
end
