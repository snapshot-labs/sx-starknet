%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import assert_not_equal
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.hash_array import HashArray
from contracts.starknet.lib.execute import execute

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

# Returns session key if it exists and hasn't expired
func get_session_key(eth_address : felt) -> (key : felt):
end

# Performs EC recover on the Ethereum signature and stores the session key in a
# mapping indexed by the recovered Ethereum address
@external
func generate_session_key_from_sig(
    r : Uint256, s : Uint256, v : felt, salt : Uint256, session_public_key : felt
):
end

# Checks signature is valid and if so, removes session key for user
@external
func revoke_session_key(sig_len : felt, sig : felt*):
end

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
    let (_public_key) = get_public_key()
    let (__fp__, _) = get_fp_and_pc()

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()
    assert data[0] = Uint256(SESSION_TYPE_HASH_LOW, SESSION_TYPE_HASH_HIGH)
    assert data[1] = ethAddress
    assert data[2] = session_public_key
    assert data[3] = session_duration
    assert data[4] = salt

    let (hash_struct) = get_keccak_hash{keccak_ptr=keccak_ptr}(5, data)

    # Prepare the encoded data
    let (prepared_encoded : Uint256*) = alloc()
    assert prepared_encoded[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH)
    assert prepared_encoded[1] = hash_struct

    # Prepend the ethereum prefix
    let (encoded_data : Uint256*) = alloc()
    prepend_prefix_2bytes(ETHEREUM_PREFIX, encoded_data, 2, prepared_encoded)

    # Now go from Uint256s to Uint64s (required in order to call `keccak`)
    let (signable_bytes) = alloc()
    let signable_bytes_start = signable_bytes
    keccak_add_uint256s{inputs=signable_bytes}(n_elements=3, elements=encoded_data, bigend=1)

    # Compute the hash
    let (hash) = keccak_bigend{keccak_ptr=keccak_ptr}(
        inputs=signable_bytes_start, n_bytes=2 * 32 + 2
    )

    # This interface expects a signature pointer and length to make
    # no assumption about signature validation schemes.
    # But this implementation does, and it expects a the sig_v, sig_r,
    # sig_s, and hash elements.
    let sig_v : felt = signature[0]
    let sig_r : Uint256 = Uint256(low=signature[1], high=signature[2])
    let sig_s : Uint256 = Uint256(low=signature[3], high=signature[4])
    let (high, low) = split_felt(hash)
    let msg_hash : Uint256 = Uint256(low=low, high=high)

    let (local keccak_ptr : felt*) = alloc()

    with keccak_ptr:
        verify_eth_signature_uint256(
            msg_hash=msg_hash, r=sig_r, s=sig_s, v=sig_v, eth_address=_public_key
        )
    end

    return (is_valid=TRUE)
end
