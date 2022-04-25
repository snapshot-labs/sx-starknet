%lang starknet
from starkware.starknet.common.syscalls import call_contract

# Forwards `data` to `target` without verifying anything.
@external
func execute{syscall_ptr : felt*, range_check_ptr}(
    to : felt, function_selector : felt, calldata_len : felt, calldata : felt*
) -> ():
    # TODO: Actually verify the signature (waiting `ecrecover` from Starkware...)

    # Call the contract
    call_contract(
        contract_address=to,
        function_selector=function_selector,
        calldata_size=calldata_len,
        calldata=calldata,
    )

    return ()
end
