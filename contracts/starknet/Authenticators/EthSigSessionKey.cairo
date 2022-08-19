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

# This is the typeHash, obtained via:
# keccak256("Vote(bytes32 space,bytes32 voterAddress,uint256 proposal,uint256 choice,bytes32 usedVotingStrategiesHash,bytes32 userVotingStrategyParamsFlatHash,uint256 salt)")
# keccak256("Session(bytes32 ethereumAddress,bytes32 sessionPublicKey,uint256 sessionDuration,uint256 salt)")
const SESSION_TYPE_HASH_HIGH = 0x0f76587b41b5c7810a4c8591d4d84385
const SESSION_TYPE_HASH_LOW = 0x85dba41961e8886710ef5d5cbe72713d

# This is the domainSeparator, obtained by using those fields (see more about it in EIP712):
# name: 'snapshot-x',
# version: '1'
# Which returns: 0x4ea062c13aa1ccc0dde3383926ef913772c5ab51b06b74e448d6b02ce79ba93c
const DOMAIN_HASH_HIGH = 0x4ea062c13aa1ccc0dde3383926ef9137
const DOMAIN_HASH_LOW = 0x72c5ab51b06b74e448d6b02ce79ba93c

@storage_var
func salts(ethAddress : felt, salt : Uint256) -> (already_used : felt):
end

# # Returns session key if it exists and hasn't expired
# func get_session_key(eth_address : felt) -> (key : felt):
# end

# # Performs EC recover on the Ethereum signature and stores the session key in a
# # mapping indexed by the recovered Ethereum address
# @external
# func generate_session_key_from_sig(
#     r : Uint256, s : Uint256, v : felt, salt : Uint256, session_public_key : felt
# ):
# end

# # Checks signature is valid and if so, removes session key for user
# @external
# func revoke_session_key(sig_len : felt, sig : felt*):
# end

# Calls get_session_key with the ethereum address (calldata[0]) to check that a session is active.
# If so, perfoms stark signature verification to check the sig is valid. If so calls execute with the payload.
# @external
# func authenticate(sig_len: felt, sig: felt*, target: felt, function_selector: felt, calldata_len: felt, calldata: felt*):
# end

func is_valid_eth_signature{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*, range_check_ptr
}(
    r : Uint256,
    s : Uint256,
    v : felt,
    salt : Uint256,
    eth_address : felt,
    session_public_key : felt,
    session_duration : felt,
) -> (is_valid : felt):
    alloc_locals

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr

    # Eth address
    let (eth_address_u256) = FeltUtils.felt_to_uint256(eth_address)
    let (padded_eth_address) = EthSigUtils.pad_right(eth_address_u256)

    # Session public key
    let (session_public_key_u256) = FeltUtils.felt_to_uint256(session_public_key)
    let (padded_session_public_key) = EthSigUtils.pad_right(session_public_key_u256)

    # Session duration
    let (session_duration_u256) = FeltUtils.felt_to_uint256(session_duration)
    let (padded_session_duration) = EthSigUtils.pad_right(session_duration_u256)

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()
    assert data[0] = Uint256(SESSION_TYPE_HASH_LOW, SESSION_TYPE_HASH_HIGH)
    assert data[1] = eth_address_u256
    assert data[2] = session_public_key_u256
    assert data[3] = session_duration_u256
    assert data[4] = salt

    let (hash_struct) = EthSigUtils.get_keccak_hash{keccak_ptr=keccak_ptr}(5, data)

    # Prepare the encoded data
    let (prepared_encoded : Uint256*) = alloc()
    assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH)
    assert prepared_encoded[1] = hash_struct

    # Prepend the ethereum prefix
    let (encoded_data : Uint256*) = alloc()
    EthSigUtils.prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded)

    # Now go from Uint256s to Uint64s (required in order to call `keccak`)
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

    return (is_valid=1)
end
