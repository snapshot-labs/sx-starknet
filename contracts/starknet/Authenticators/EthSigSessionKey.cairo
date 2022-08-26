%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import split_felt, assert_le, assert_not_zero
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eip712 import EIP712
from contracts.starknet.lib.session_key import SessionKey

# Calls get_session_key with the ethereum address (calldata[0]) to check that a session is active.
# If so, perfoms stark signature verification to check the sig is valid. If so calls execute with the payload.
@external
func authenticate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sig_len : felt,
    sig : felt*,
    session_public_key : felt,
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
):
    # TO DO: Verify stark signature

    # Check session key is active
    let (eth_address) = SessionKey.get_session_key(session_public_key)

    # Check user's address is equal to the owner of the session key
    with_attr error_message("Invalid Ethereum address"):
        assert calldata[0] = eth_address
    end

    # foreward payload to target
    execute(target, function_selector, calldata_len, calldata)

    return ()
end

# Performs EC recover on the Ethereum signature and stores the session key in a
# mapping indexed by the recovered Ethereum address
@external
func authorize_session_key_from_sig{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*, range_check_ptr
}(
    r : Uint256,
    s : Uint256,
    v : felt,
    salt : Uint256,
    eth_address : felt,
    session_public_key : felt,
    session_duration : felt,
):
    EIP712.verify_session_key_sig(r, s, v, salt, eth_address, session_public_key, session_duration)
    SessionKey.register_session_key(eth_address, session_public_key, session_duration)
    return ()
end

# Checks signature is valid and if so, removes session key for user
@external
func revoke_session_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sig_len : felt, sig : felt*, session_public_key : felt
):
    # TO DO: sig verification

    SessionKey.revoke_session_key(sig_len, sig, session_public_key)
    return ()
end
