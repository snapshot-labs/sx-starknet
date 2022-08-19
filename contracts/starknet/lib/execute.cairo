from starkware.starknet.common.syscalls import call_contract

func execute{syscall_ptr : felt*, range_check_ptr}(
    target : felt, function_selector : felt, calldata_len : felt, calldata : felt*
) -> ():
    call_contract(
        contract_address=target,
        function_selector=function_selector,
        calldata_size=calldata_len,
        calldata=calldata,
    )
    return ()
end
