%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import uint256_eq

@external
func authenticate{syscall_ptr : felt*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    target : felt, function_selector : felt, calldata_len : felt, calldata : felt*
) -> ():
    alloc_locals

    let (caller_address) = get_caller_address()
    let (caller_address_u256) = felt_to_uint256(caller_address)

    let (calldata_address) = felt_to_uint256(calldata[0])

    # Verify that proposer / voter address is the caller
    let (is_equal) = uint256_eq(calldata_address, caller_address_u256)

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end
