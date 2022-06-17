%lang starknet

from starkware.cairo.common.uint256 import Uint256, uint256_eq
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import call_contract
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.messages import send_message_to_l1
from contracts.starknet.lib.proposal_outcome import ProposalOutcome
from contracts.starknet.lib.hash_array import hash_array
from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.account.library import AccountCallArray, Call

# Starknet execution strategy
# execution_params expected layout:
# execution_params[0]: data_offset
# execution_params[1]: `to`
# execution_params[2]: `function_selector`
# execution_params[3]: `calldata_size`
# execution_params[4]: `calldata_offset`
# execution_params[5]: `to` (second call)
# execution_params[6]: `function_selector` (second call)
# execution_params[7]: `calldata_size` (second call)
# execution_params[8]: `calldata_offset` (second call)
# execution_params[9]: `to` (third call)
# etc...
#
# For example: say the contract wants to interact with the contract `0x123` with selector `0x456` that takes two arguments (we will give 13 and 37 as values),
# and then interact with contract `0x789` with selector `0xabc` that takes three arguments (we will give 42 43 44 as values):
# execution_params= [9, [0x123, 0x456, 2, 0, [0x789, 0xabc, 3, 2, 13, 37, 42, 43, 44]

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
func execute{syscall_ptr : felt*, range_check_ptr : felt, pedersen_ptr : HashBuiltin*}(
    proposal_outcome : felt, execution_params_len : felt, execution_params : felt*
):
    alloc_locals
    # assert execution_params_len = 1
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
