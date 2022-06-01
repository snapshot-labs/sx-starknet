%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_keccak.keccak import keccak_uint256s_bigend
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint

const PROPOSAL_SELECTOR = 1
const VOTE_SELECTOR = 2

const BYTES_IN_UINT256 = 32

const ETHEREUM_PREFIX = 0x1901

# keccak256("Propose(uint256 nonce,bytes32 space,bytes32 executionHash,string metadataURI)")
# 0xb165e31e54251c4e587d1ab2c6d929b2471c024bf48d00ebc9ca94777b0aa13d
const PROPOSAL_HASH_LOW = 0x471c024bf48d00ebc9ca94777b0aa13d
const PROPOSAL_HASH_HIGH = 0xb165e31e54251c4e587d1ab2c6d929b2

# keccak256("Vote(uint256 nonce,bytes32 space,uint256 proposal,uint256 choice)")
# 0x5a6ef60fd4d9b84327ba5c43cada66cd075ba32fff928b67c45d391a0bfac1c0
const VOTE_HASH_LOW = 0x75ba32fff928b67c45d391a0bfac1c0
const VOTE_HASH_HIGH = 0x5a6ef60fd4d9b84327ba5c43cada66cd

# keccak256("EIP712Domain(string name,string version)")
# 0xb03948446334eb9b2196d5eb166f69b9d49403eb4a12f36de8d3f9f3cb8e15c3
const DOMAIN_HASH_LOW = 0xb03948446334eb9b2196d5eb166f69b9
const DOMAIN_HASH_HIGH = 0xd49403eb4a12f36de8d3f9f3cb8e15c3

func add_prefix{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(value : felt, prefix : felt) -> (
        result : felt, overflow):
    let shifted_prefix = prefix * 2 ** 128
    # with_prefix is 18 bytes long
    let with_prefix = shifted_prefix + value
    let overflow_mask = 2 ** 16 - 1
    let (overflow) = bitwise_and(with_prefix, overflow_mask)
    let result = (with_prefix - overflow) / 2 ** 16
    return (result, overflow)
end

func get_hash(calldata_len : felt, calldata : felt*) -> (hash : Uint256):
    return (Uint256(0, 0))
end

func authenticate_proposal{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(msg_hash: Uint256, r: Uint256, s: Uint256, v: felt, eth_address: felt, nonce : Uint256, target : felt, calldata_len : felt, calldata : felt*):
    alloc_locals

    let (local keccak_ptr : felt*) = alloc()
    verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(msg_hash, r, s, v, eth_address)

    # execution_hash should be in calldata[2] and calldata[3]
    let execution_hash = Uint256(calldata[2], calldata[3])

    # Space should be the target, but encoded as uint256
    let (space) = felt_to_uint256(target)

    # metadata_uri_len should be in calldata[4]
    let metadata_uri_len = calldata[4]
    # metadata_uri pointer should be in calldata[5]
    # let metadata_uri = cast(calldata[5], felt*)

    # now construct the hash
    let (encoded_data: Uint256*) = alloc()

    assert encoded_data[0] = Uint256(PROPOSAL_HASH_LOW, PROPOSAL_HASH_HIGH)

    assert encoded_data[1] = nonce

    assert encoded_data[2] = execution_hash

    # let metadata_uri_hash = Uint256(0, 0)
    # assert encoded_data[3] = metadata_uri_hash

    let (local keccak_ptr : felt*) = alloc()
    let (data_hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(3 * BYTES_IN_UINT256, encoded_data)

    let (w1, prefix) = add_prefix(DOMAIN_HASH_HIGH, ETHEREUM_PREFIX)
    let (w0, prefix) = add_prefix(DOMAIN_HASH_LOW, prefix)

    let (w3, prefix) = add_prefix(data_hash.high, prefix)
    let (w2, overflow) = add_prefix(data_hash.low, prefix)

    let (signable_bytes : Uint256*) = alloc()
    assert signable_bytes[0] = Uint256(w0, w1)
    assert signable_bytes[1] = Uint256(w2, w3)
    assert signable_bytes[2] = Uint256(overflow, 0)

    let (local keccak_ptr : felt*) = alloc()
    let (recovered_hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(2 * BYTES_IN_UINT256 + 2, signable_bytes)
    
    let (local keccak_ptr : felt*) = alloc()
    verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(recovered_hash, r, s, v, eth_address)

    return ()
end

func authenticate_vote{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(nonce : Uint256, target : felt, calldata_len : felt, calldata : felt*):
    return ()
end

@external
func authenticate{syscall_ptr : felt*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    msg_hash: Uint256, r: Uint256, s: Uint256, v: felt, eth_address: felt, nonce : Uint256, target : felt, function_selector : felt, calldata_len : felt, calldata : felt*
) -> ():
    if function_selector == PROPOSAL_SELECTOR:
        authenticate_proposal(msg_hash, r, s, v, eth_address, nonce, target, calldata_len, calldata)
    else:
        authenticate_vote(nonce, target, calldata_len, calldata)
    end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end
