%lang starknet
from starkware.starknet.common.syscalls import call_contract

# Forwards `data` to `target` without verifying anything.
@external
func execute{syscall_ptr : felt*, range_check_ptr}(
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
    signer_len : felt,
    signer : felt*,
    signature_len : felt,
    signature : felt*,
) -> ():
    # TODO: Actually verify the signature

    # Call the contract
    call_contract(
        contract_address=target,
        function_selector=function_selector,
        calldata_size=calldata_len,
        calldata=calldata,
    )

    return ()
end
