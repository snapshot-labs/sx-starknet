%lang starknet

from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import call_contract
from contracts.starknet.lib.proposal_outcome import ProposalOutcome

# Starknet Execution
# This is more of a demo as we need to interact with a wallet to execute meaningful transactions.

# Example execution: say the contract wants to interact with the contract `0x123` with selector `0x456` that takes two arguments (we will give 13 and 37 as values),
# and then interact with contract `0x789` with selector `0xabc` that takes three arguments (we will give 42 43 44 as values):
# [9, 0x123, 0x456, 2, 0, 0x789, 0xabc, 3, 2, 13, 37, 42, 43, 44]
func execute_calls{syscall_ptr : felt*}(data_ptr : felt*, calls_len : felt, calls : felt*):
    if calls_len == 0:
        return ()
    end

    let res = call_contract(
        contract_address=calls[0],
        function_selector=calls[1],
        calldata_size=calls[2],
        calldata=&data_ptr[calls[3]],
    )

    # TODO: what should we do with the return values?

    # Do the next calls recursively
    # We subtract `4` + calls[2]` because a `call` has 4 felts and we also need to substract its associated calldata length.
    execute_calls(data_ptr, calls_len - (4 + calls[2]), calls + 4)

    return ()
end

@external
func execute{syscall_ptr : felt*, range_check_ptr : felt}(
    proposal_outcome : felt, execution_params_len : felt, execution_params : felt*
):
    alloc_locals
    # Check that there are `Calls` ton execute in the execution parameters.
    let (is_lower) = is_le(execution_params_len, 4)
    if is_lower == 1:
        return ()
    end

    if proposal_outcome == ProposalOutcome.ACCEPTED:
        # The calldata offset is located in the first parameter
        let data_offset = execution_params[0]

        # Execute the calls
        execute_calls(
            &execution_params[data_offset], execution_params_len - 1, &execution_params[1]
        )
        return ()
    else:
        return ()
    end
end
