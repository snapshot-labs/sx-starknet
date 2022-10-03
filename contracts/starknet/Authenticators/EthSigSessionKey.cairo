%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import split_felt, assert_le, assert_not_zero
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eip712 import EIP712
from contracts.starknet.lib.stark_eip191 import StarkEIP191
from contracts.starknet.lib.session_key import SessionKey

// getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81;
// getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41;

// Calls get_session_key with the ethereum address (calldata[0]) to check that a session is active.
// If so, perfoms stark signature verification to check the sig is valid. If so calls execute with the payload.
@external
func authenticate{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(
    r: felt,
    s: felt,
    salt: felt,
    target: felt,
    function_selector: felt,
    calldata_len: felt,
    calldata: felt*,
    session_public_key: felt,
) {
    let eth_address = calldata[0];
    SessionKey.assert_valid(session_public_key, eth_address);

    // Check signature with session key
    if (function_selector == PROPOSAL_SELECTOR) {
        StarkEIP191.verify_propose_sig(
            r, s, salt, target, calldata_len, calldata, session_public_key
        );
    } else {
        if (function_selector == VOTE_SELECTOR) {
            StarkEIP191.verify_vote_sig(
                r, s, salt, target, calldata_len, calldata, session_public_key
            );
        } else {
            // Invalid selector
            return ();
        }
    }

    // Call the contract
    execute(target, function_selector, calldata_len, calldata);

    return ();
}

// Performs EC recover on the Ethereum signature and stores the session key in a
// mapping indexed by the recovered Ethereum address
@external
func authorize_session_key_with_sig{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
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
    SessionKey.authorize_with_sig(r, s, v, salt, eth_address, session_public_key, session_duration);
    return ();
}

// Checks signature is valid and if so, removes session key for user
@external
func revoke_session_key_with_session_key_sig{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(r: felt, s: felt, salt: felt, session_public_key: felt) {
    SessionKey.revoke_with_session_key_sig(r, s, salt, session_public_key);
    return ();
}

// Checks signature is valid and if so, removes session key for user
@external
func revoke_session_key_with_owner_sig{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
    ecdsa_ptr: SignatureBuiltin*,
}(r: Uint256, s: Uint256, v: felt, salt: Uint256, session_public_key: felt) {
    SessionKey.revoke_with_owner_sig(r, s, v, salt, session_public_key);
    return ();
}

// Public view function for checking a session key
@view
func get_session_key_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    session_public_key: felt
) -> (eth_address: felt) {
    let (eth_address) = SessionKey.get_owner(session_public_key);
    return (eth_address,);
}
