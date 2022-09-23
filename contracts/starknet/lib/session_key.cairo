%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_not_zero
from starkware.cairo.common.alloc import alloc

from contracts.starknet.lib.stark_eip191 import StarkEIP191
from contracts.starknet.lib.eip712 import EIP712
from contracts.starknet.lib.eth_tx import EthTx
from contracts.starknet.lib.hash_array import HashArray

@storage_var
func SessionKey_owner_store(session_public_key: felt) -> (eth_address: felt) {
}

@storage_var
func SessionKey_end_timestamp_store(session_public_key: felt) -> (timestamp: felt) {
}

@event
func session_key_registered(eth_address: felt, session_public_key: felt, session_duration: felt) {
}

@event
func session_key_revoked(session_public_key: felt) {
}

namespace SessionKey {
    func authorize_with_sig{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(
        r: Uint256,
        s: Uint256,
        v: felt,
        salt: Uint256,
        eth_address: felt,
        session_public_key: felt,
        session_duration: felt,
    ) {
        alloc_locals;
        EIP712.verify_session_key_init_sig(
            r, s, v, salt, eth_address, session_public_key, session_duration
        );
        _register(eth_address, session_public_key, session_duration);
        return ();
    }

    func authorize_with_tx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        eth_address: felt, session_public_key: felt, session_duration: felt
    ) {
        alloc_locals;
        // Cast arguments to single array and hash them
        let (commit_array: felt*) = alloc();
        assert commit_array[0] = eth_address;
        assert commit_array[1] = session_public_key;
        assert commit_array[2] = session_duration;
        let (commit_hash) = HashArray.hash_array(3, commit_array);

        // Checks that the hash matches a commit and that the commit was created by the correct address
        EthTx.consume_commit(commit_hash, eth_address);

        _register(eth_address, session_public_key, session_duration);
        return ();
    }

    func revoke_with_session_key_sig{
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
    }(r: felt, s: felt, salt: felt, session_public_key: felt) {
        alloc_locals;
        let (eth_address) = SessionKey_owner_store.read(session_public_key);
        with_attr error_message("Session does not exist") {
            assert_not_zero(eth_address);
        }
        StarkEIP191.verify_session_key_revoke_sig(r, s, salt, session_public_key);
        _revoke(session_public_key);
        return ();
    }

    func revoke_with_owner_sig{
        syscall_ptr: felt*,
        range_check_ptr,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
    }(r: Uint256, s: Uint256, v: felt, salt: Uint256, session_public_key: felt) {
        alloc_locals;
        let (eth_address) = SessionKey_owner_store.read(session_public_key);
        with_attr error_message("Session does not exist") {
            assert_not_zero(eth_address);
        }
        EIP712.verify_session_key_revoke_sig(r, s, v, salt, eth_address, session_public_key);
        _revoke(session_public_key);
        return ();
    }

    func revoke_with_owner_tx{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        session_public_key: felt
    ) {
        alloc_locals;
        let (eth_address) = SessionKey_owner_store.read(session_public_key);
        with_attr error_message("Session does not exist") {
            assert_not_zero(eth_address);
        }
        let (commit_array: felt*) = alloc();
        assert commit_array[0] = eth_address;
        assert commit_array[1] = session_public_key;
        let (commit_hash) = HashArray.hash_array(2, commit_array);

        // Checks that hash maches a commit and that the commit was created by the correct address
        EthTx.consume_commit(commit_hash, eth_address);

        _revoke(session_public_key);

        return ();
    }

    // Returns owner of a session key if it exists, otherwise throws
    func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        session_public_key: felt
    ) -> (eth_address: felt) {
        let (eth_address) = SessionKey_owner_store.read(session_public_key);
        with_attr error_message("Session does not exist") {
            assert_not_zero(eth_address);
        }

        let (end_timestamp) = SessionKey_end_timestamp_store.read(session_public_key);
        let (current_timestamp) = get_block_timestamp();
        with_attr error_message("Session has ended") {
            assert_le(current_timestamp, end_timestamp);
        }
        return (eth_address,);
    }
}

func _register{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    eth_address: felt, session_public_key: felt, session_duration: felt
) {
    SessionKey_owner_store.write(session_public_key, eth_address);
    let (current_timestamp) = get_block_timestamp();
    let end_timestamp = current_timestamp + session_duration;
    with_attr error_message("Overflow in Session duration, use smaller value") {
        assert_le(current_timestamp, end_timestamp);
    }
    SessionKey_end_timestamp_store.write(session_public_key, current_timestamp + session_duration);
    session_key_registered.emit(eth_address, session_public_key, session_duration);
    return ();
}

func _revoke{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    session_public_key: felt
) {
    SessionKey_owner_store.write(session_public_key, 0);
    session_key_revoked.emit(session_public_key);
    return ();
}
