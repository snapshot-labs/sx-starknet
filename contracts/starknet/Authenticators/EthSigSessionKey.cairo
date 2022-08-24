%lang starknet

from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_utils import FeltUtils
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from contracts.starknet.lib.eth_sig_utils import EthSigUtils

const ETHEREUM_PREFIX = 0x1901

# keccak256("SessionKey(bytes32 address,bytes32 sessionPublicKey,bytes32 sessionDuration,uint256 salt)")
const SESSION_KEY_TYPE_HASH_HIGH = 0x233b93cc8989df29b5834cd69e96f1e9
const SESSION_KEY_TYPE_HASH_LOW = 0x390b13389ac2a65080907f1fcf6385e8

# This is the domainSeparator, obtained by using those fields (see more about it in EIP712):
# name: 'snapshot-x',
# version: '1'
# Which returns: 0x4ea062c13aa1ccc0dde3383926ef913772c5ab51b06b74e448d6b02ce79ba93c
const DOMAIN_HASH_HIGH = 0x4ea062c13aa1ccc0dde3383926ef9137
const DOMAIN_HASH_LOW = 0x72c5ab51b06b74e448d6b02ce79ba93c

@storage_var
func salts(eth_address : felt, salt : Uint256) -> (already_used : felt):
end

@storage_var
func session_key_owner(session_public_key : felt) -> (eth_address):
end

# Returns owner of a session key if it exists, otherwise returns 0
@external
func get_session_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    session_public_key : felt
) -> (eth_address : felt):
    let (eth_address) = session_key_owner.read(session_public_key)
    return (eth_address)
end

# # Checks signature is valid and if so, removes session key for user
# @external
# func revoke_session_key(sig_len : felt, sig : felt*):
# end

# Calls get_session_key with the ethereum address (calldata[0]) to check that a session is active.
# If so, perfoms stark signature verification to check the sig is valid. If so calls execute with the payload.
# @external
# func authenticate(sig_len: felt, sig: felt*, target: felt, function_selector: felt, calldata_len: felt, calldata: felt*):
# end

# Performs EC recover on the Ethereum signature and stores the session key in a
# mapping indexed by the recovered Ethereum address
@external
func generate_session_key_from_sig{
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
    check_eth_signature(r, s, v, salt, eth_address, session_public_key, session_duration)
    session_key_owner.write(session_public_key, eth_address)
    return ()
end

func check_eth_signature{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*, range_check_ptr
}(
    r : Uint256,
    s : Uint256,
    v : felt,
    salt : Uint256,
    eth_address : felt,
    session_public_key : felt,
    session_duration : felt,
) -> ():
    alloc_locals

    # Ensure voter has not already used this salt in a previous action
    let (already_used) = salts.read(eth_address, salt)
    with_attr error_message("Salt already used"):
        assert already_used = 0
    end

    # Encode data
    let (eth_address_u256) = FeltUtils.felt_to_uint256(eth_address)
    let (padded_eth_address) = EthSigUtils.pad_right(eth_address_u256)
    let (session_public_key_u256) = FeltUtils.felt_to_uint256(session_public_key)
    let (padded_session_public_key) = EthSigUtils.pad_right(session_public_key_u256)
    let (session_duration_u256) = FeltUtils.felt_to_uint256(session_duration)
    let (padded_session_duration) = EthSigUtils.pad_right(session_duration_u256)

    # Now construct the data array
    let (data : Uint256*) = alloc()
    assert data[0] = Uint256(SESSION_KEY_TYPE_HASH_LOW, SESSION_KEY_TYPE_HASH_HIGH)
    assert data[1] = padded_eth_address
    assert data[2] = padded_session_public_key
    assert data[3] = padded_session_duration
    assert data[4] = salt

    # Hash the data array
    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr
    let (hash_struct) = EthSigUtils.get_keccak_hash{keccak_ptr=keccak_ptr}(5, data)

    # Prepend the domain separator hash
    let (prepared_encoded : Uint256*) = alloc()
    assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH)
    assert prepared_encoded[1] = hash_struct

    # Prepend the ethereum prefix
    let (encoded_data : Uint256*) = alloc()
    EthSigUtils.prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded)

    # Now go from Uint256s to Uint64s (required for the cairo keccak implementation)
    let (signable_bytes) = alloc()
    let signable_bytes_start = signable_bytes
    keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1)

    # Compute the hash
    let (msg_hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
        inputs=signable_bytes_start, n_bytes=2 * 32 + 2
    )

    # `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
    # We substract `27` because `v` = `{0, 1} + 27`
    verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(msg_hash, r, s, v - 27, eth_address)

    # Verify that all the previous keccaks are correct
    finalize_keccak(keccak_ptr_start, keccak_ptr)

    # Write the salt to prevent replay attack
    salts.write(eth_address, salt, 1)

    return ()
end
