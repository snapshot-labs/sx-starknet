%lang starknet
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starknet.lib.words import Words, felt_to_words

@view
func test_felt_to_words{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(input : felt) -> (
    words : Words
):
    let (words) = felt_to_words(input)
    return (words)
end
