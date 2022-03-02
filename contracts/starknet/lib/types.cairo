from starkware.cairo.common.math import assert_nn_le, assert_lt_felt

struct EthAddress:
    member value : felt
end

# Checks that input is 160 bits long then if so, casts to the EthAddress type.
func to_ethereum_address{range_check_ptr}(input : felt) -> (address : EthAddress):
    assert_lt_felt(input, 2 ** 160)
    tempvar address : EthAddress = EthAddress(value=input)
    return (address)
end
