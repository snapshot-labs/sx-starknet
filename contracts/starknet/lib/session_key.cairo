%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import split_felt, assert_le, assert_not_zero
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)

from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_utils import FeltUtils
from contracts.starknet.lib.eth_sig_utils import EthSigUtils

@storage_var
func SessionKey_owner(session_public_key : felt) -> (eth_address : felt):
end

@storage_var
func SessionKey_end_timestamp(session_public_key : felt) -> (timestamp : felt):
end

@event
func session_key_registered(eth_address : felt, session_public_key : felt, session_duration : felt):
end

@event
func session_key_revoked(session_public_key : felt):
end

namespace SessionKey:
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
        # Verify stark signature

        # Check session key is active
        let (eth_address) = get_session_key(session_public_key)

        # Check user's address is equal to the owner of the session key
        with_attr error_message("Invalid Ethereum address"):
            assert calldata[0] = eth_address
        end

        # foreward payload to target
        execute(target, function_selector, calldata_len, calldata)

        return ()
    end

    # Checks signature is valid and if so, removes session key for user
    @external
    func revoke_session_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sig_len : felt, sig : felt*, session_public_key : felt
    ):
        # Verify stark signature

        # Set session key owner to zero
        SessionKey_owner.write(session_public_key, 0)
        session_key_revoked.emit(session_public_key)
        return ()
    end

    func register_session_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        eth_address : felt, session_public_key : felt, session_duration : felt
    ):
        SessionKey_owner.write(session_public_key, eth_address)
        let (current_timestamp) = get_block_timestamp()
        SessionKey_end_timestamp.write(session_public_key, current_timestamp + session_duration)
        session_key_registered.emit(eth_address, session_public_key, session_duration)
        return ()
    end

    # Returns owner of a session key if it exists, otherwise returns 0
    func get_session_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        session_public_key : felt
    ) -> (eth_address : felt):
        let (eth_address) = SessionKey_owner.read(session_public_key)
        with_attr error_message("Session does not exist"):
            assert_not_zero(eth_address)
        end

        let (end_timestamp) = SessionKey_end_timestamp.read(session_public_key)
        let (current_timestamp) = get_block_timestamp()
        with_attr error_message("Session has ended"):
            assert_le(current_timestamp, end_timestamp)
        end
        return (eth_address)
    end
end
