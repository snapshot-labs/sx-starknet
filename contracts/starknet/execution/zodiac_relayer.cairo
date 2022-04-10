%lang starknet

from contracts.starknet.lib.eth_address import EthAddress
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.messages import send_message_to_l1

@external
func execute{syscall_ptr : felt*}(
        has_passed : felt, execution_hash : Uint256, execution_params_len : felt,
        execution_params : felt*):
    alloc_locals

    let (caller_address) = get_caller_address()

    # Get the l1 zodiac address
    assert execution_params_len = 1
    let l1_zodiac_address = execution_params[0]

    # Create the payload
    let (message_payload : felt*) = alloc()
    assert message_payload[0] = caller_address
    assert message_payload[1] = has_passed
    assert message_payload[2] = execution_hash.low
    assert message_payload[3] = execution_hash.high

    let payload_size = 4

    # Send message to L1 Contract
    send_message_to_l1(
        to_address=l1_zodiac_address, payload_size=payload_size, payload=message_payload)
    return ()
end
