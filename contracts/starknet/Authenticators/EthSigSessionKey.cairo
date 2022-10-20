// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)

from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.eip712 import EIP712
from contracts.starknet.lib.stark_eip191 import StarkEIP191
from contracts.starknet.lib.session_key import SessionKey

//
// @title Session key Authenticator with Ethereum Signature Authorization
// @author SnapshotLabs
// @notice Contract to allow authentication with a session key that can be authorized and revoked with an Ethereum signature
//

// getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81;
// getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41;

// @dev Authentication of an action (vote or propose) via a StarkNet session key signature
// @param r Signature parameter
// @param s Signature parameter
// @param salt Signature salt
// @param target Address of the space contract
// @param function_selector Function selector of the action
// @param calldata Calldata array required for the action
// @param session_public_key The StarkNet session public key that was used to generate the signature
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
    execute(target, function_selector, calldata_len, calldata);
    return ();
}

// @dev Registers a session key via authorization from an Ethereum signature
// @param r Signature parameter
// @param s Signature parameter
// @param v Signature parameter
// @param salt Signature salt
// @param eth_address Owner's Ethereum Address that was used to create the signature
// @param session_public_key The StarkNet session public key that should be registered
// @param session_duration The number of seconds that the session key is valid
@external
func authorizeSessionKeyWithSig{
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

// @dev Revokes a session key via authorization from a signature from the session key itself
// @param r Signature parameter
// @param s Signature parameter
// @param salt Signature salt
// @param session_public_key The StarkNet session public key that should be revoked
@external
func revokeSessionKeyWithSessionKeySig{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(r: felt, s: felt, salt: felt, session_public_key: felt) {
    SessionKey.revoke_with_session_key_sig(r, s, salt, session_public_key);
    return ();
}

// @dev Revokes a session key via authorization from a signature from the owner Ethereum account
// @param r Signature parameter
// @param s Signature parameter
// @param v Signature parameter
// @param salt Signature salt
// @param session_public_key The StarkNet session public key that should be revoked
@external
func revokeSessionKeyWithOwnerSig{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
    ecdsa_ptr: SignatureBuiltin*,
}(r: Uint256, s: Uint256, v: felt, salt: Uint256, session_public_key: felt) {
    SessionKey.revoke_with_owner_sig(r, s, v, salt, session_public_key);
    return ();
}

// @dev Returns owner of a session key if it exists, otherwise throws
// @param session_public_key The StarkNet session public key
// @return owner The owner Ethereum address
@view
func getSessionKeyOwner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    session_public_key: felt
) -> (eth_address: felt) {
    let (eth_address) = SessionKey.get_owner(session_public_key);
    return (eth_address,);
}
