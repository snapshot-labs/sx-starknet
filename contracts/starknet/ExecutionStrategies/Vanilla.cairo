%lang starknet

@external
func execute{syscall_ptr : felt*}(
    proposal_outcome : felt, execution_params_len : felt, execution_params : felt*
):
    return ()
end
