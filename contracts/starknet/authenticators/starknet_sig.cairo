%lang starknet

from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import uint256_eq
# from openzeppelin.account.IAccount import IAccount

@external
func authenticate{syscall_ptr : felt*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    hash : felt, # TODO: change this to actual data, not simply the hash
    sig_len : felt,
    sig : felt*,
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
) -> ():
    # Voter address or proposer address should be located in calldata[0]
    let user_address = calldata[0]

    # Will throw if signature is invalid
    # with_attr error_message("Invalid signature"):
    #     IAccount.is_valid_signature(
    #         contract_address=user_address, hash=hash, signature_len=sig_len, signature=sig
    #     )
    # end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end
