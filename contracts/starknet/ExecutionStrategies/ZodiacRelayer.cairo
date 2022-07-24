%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.messages import send_message_to_l1

@external
func execute{syscall_ptr : felt*}(
    proposal_outcome : felt, execution_params_len : felt, execution_params : felt*
):
    alloc_locals

    let (caller_address) = get_caller_address()

    # For the zodiac execution strategy, the execution parameters has 3 elements
    with_attr error_message("Invalid execution param array"):
        assert execution_params_len = 3
    end
    let l1_zodiac_address = execution_params[0]
    let execution_hash_low = execution_params[1]
    let execution_hash_high = execution_params[2]

    # Create the payload
    let (message_payload : felt*) = alloc()
    assert message_payload[0] = caller_address
    assert message_payload[1] = proposal_outcome
    assert message_payload[2] = execution_hash_low
    assert message_payload[3] = execution_hash_high

    let payload_size = 4

    # Send message to L1 Contract
    send_message_to_l1(
        to_address=l1_zodiac_address, payload_size=payload_size, payload=message_payload
    )
    return ()
end
