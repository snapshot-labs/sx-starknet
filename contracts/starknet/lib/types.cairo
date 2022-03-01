from starkware.cairo.common.math import assert_nn_le, assert_lt_felt

struct EthereumAddress:
    member value : felt
end

# Checks that input is 160 bits long then if so, casts to the EthereumAddress type.
func to_ethereum_address{range_check_ptr}(input : felt) -> (address : EthereumAddress):
    assert_lt_felt(input, 2 ** 160)
    tempvar address : EthereumAddress = EthereumAddress(value=input)
    return (address)
end
