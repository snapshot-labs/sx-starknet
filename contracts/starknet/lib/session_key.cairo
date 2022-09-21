%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_le, assert_not_zero

from contracts.starknet.lib.stark_eip191 import StarkEIP191

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
    func register_session_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        eth_address : felt, session_public_key : felt, session_duration : felt
    ):
        SessionKey_owner.write(session_public_key, eth_address)
        let (current_timestamp) = get_block_timestamp()
        SessionKey_end_timestamp.write(session_public_key, current_timestamp + session_duration)
        session_key_registered.emit(eth_address, session_public_key, session_duration)
        return ()
    end

    func revoke_session_key{
        syscall_ptr : felt*,
        range_check_ptr,
        pedersen_ptr : HashBuiltin*,
        ecdsa_ptr : SignatureBuiltin*,
    }(r : felt, s : felt, salt : felt, session_public_key : felt):
        StarkEIP191.verify_session_key_sig(r, s, salt, session_public_key)
        SessionKey_owner.write(session_public_key, 0)
        session_key_revoked.emit(session_public_key)
        return ()
    end

    # Returns owner of a session key if it exists, otherwise returns 0
    func get_session_key_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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
