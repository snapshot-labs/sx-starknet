%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_mul, uint256_unsigned_div_rem, uint256_sub
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_keccak.keccak import keccak_uint256s, keccak_uint256s_bigend, keccak_add_uint256s, keccak_bigend, keccak
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import split_felt

# TODO maybe use OZ safemath when possible?

# getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81
# getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41

const BYTES_IN_UINT256 = 32

const ETHEREUM_PREFIX = 0x1901

# keccak256("Propose(uint256 nonce,bytes32 space,bytes32 executionHash,string metadataURI)")
# 0xb165e31e54251c4e587d1ab2c6d929b2471c024bf48d00ebc9ca94777b0aa13d
# const PROPOSAL_HASH_LOW = 0x471c024bf48d00ebc9ca94777b0aa13d
# const PROPOSAL_HASH_HIGH = 0xb165e31e54251c4e587d1ab2c6d929b2

# TYPEHASH
# keccak256("Propose(uint256 nonce,bytes32 space,bytes32 executionHash)")
# 0x5cfc4702ffe6f2fcfeddf8dbd302af4e5107f419dd58831c07caa583b578c055
const PROPOSAL_HASH_HIGH = 0x5cfc4702ffe6f2fcfeddf8dbd302af4e
const PROPOSAL_HASH_LOW = 0x5107f419dd58831c07caa583b578c055

# LEFT_PADDED 1: 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6
const NONCE_HASH_HIGH = 0xb10e2d527612073b26eecdfd717e6a32
const NONCE_HASH_LOW = 0x0cf44b4afac2b0732d9fcbe2b7fa0cf6

# NO_PAD 1: 0x5fe7f977e71dba2ea1a68e21057beebb9be2ac30c6410aa38d4f3fbe41dcffd2
# const NONCE_HASH_HIGH = 0x5fe7f977e71dba2ea1a68e21057beebb
# const NONCE_HASH_LOW = 0x9be2ac30c6410aa38d4f3fbe41dcffd2

# keccak256("Vote(uint256 nonce,bytes32 space,uint256 proposal,uint256 choice)")
# 0x5a6ef60fd4d9b84327ba5c43cada66cd075ba32fff928b67c45d391a0bfac1c0
const VOTE_HASH_HIGH = 0x5a6ef60fd4d9b84327ba5c43cada66cd
const VOTE_HASH_LOW = 0x75ba32fff928b67c45d391a0bfac1c0

# encodedData = hexConcat([prefixWithZeroes("1"), hexPadRight(message.space), hexPadRight(message.executionHash)]);
# keccak256(hexConcat([typehash, encodedData])
# const DATA_HASH = 0xb520b9bdd0518376add84979bcbdf94b18e923a885a86371bce7342755eb54be
# const DATA_HASH_HIGH = 0xb520b9bdd0518376add84979bcbdf94b
# const DATA_HASH_LOW = 0x18e923a885a86371bce7342755eb54be

# keccak256("EIP712Domain(string name,string version)")
# 0xb03948446334eb9b2196d5eb166f69b9d49403eb4a12f36de8d3f9f3cb8e15c3
# const DOMAIN_HASH_HIGH = 0xb03948446334eb9b2196d5eb166f69b9
# const DOMAIN_HASH_LOW = 0xd49403eb4a12f36de8d3f9f3cb8e15c3

# DOMAIN HASH
# keccak256(EIP712Domain(string name, string version) ??? (name snapshot-x,version 1)
# 0x4ea062c13aa1ccc0dde3383926ef913772c5ab51b06b74e448d6b02ce79ba93c
const DOMAIN_HASH_HIGH = 0x4ea062c13aa1ccc0dde3383926ef9137
const DOMAIN_HASH_LOW = 0x72c5ab51b06b74e448d6b02ce79ba93c

func add_prefix64{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(value : felt, prefix : felt) -> (
        result : felt, overflow):
    let shifted_prefix = prefix * 2 ** 64
    # with_prefix is 10 bytes long
    let with_prefix = shifted_prefix + value
    let overflow_mask = 2 ** 16 - 1
    let (overflow) = bitwise_and(with_prefix, overflow_mask) # TODO: should we use div_mod instead (to use modulus?)
    let result = (with_prefix - overflow) / 2 ** 16
    return (result, overflow)
end

# value has to be a 16 byte word
# prefix length = PREFIX_BITS
func add_prefix128{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(value : felt, prefix : felt) -> (
        result : felt, overflow):
    let shifted_prefix = prefix * 2 ** 128
    # with_prefix is 18 bytes long
    let with_prefix = shifted_prefix + value
    let overflow_mask = 2 ** 16 - 1
    let (overflow) = bitwise_and(with_prefix, overflow_mask)
    let result = (with_prefix - overflow) / 2 ** 16 # TODO: remove -overflow?
    return (result, overflow)
end

func prepend_prefix{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(prefix: felt, output: Uint256*, input_len: felt, input: Uint256*):
    if input_len == 0:
        assert output[0] = Uint256(0, prefix * 16 ** 28)
        return ()
    else:
        let num = input[0]
        let (w1, prefix) = add_prefix128(num.high, prefix)
        let (w0, prefix) = add_prefix128(num.low, prefix)

        let res = Uint256(w0, w1)
        assert output[0] = res

        prepend_prefix(prefix, &output[1], input_len - 1, &input[1])
        return ()
    end
end

func keccak_uint256s_precise_bytes{range_check_ptr, bitwise_ptr : BitwiseBuiltin*, keccak_ptr : felt*}(
    n_elements : felt, elements : Uint256*
) -> (res : Uint256):
    alloc_locals

    let (prefixed_uints: Uint256*) = alloc()
    prepend_prefix(ETHEREUM_PREFIX, prefixed_uints, n_elements, elements)

    let (signable_bytes) = alloc()
    let signable_bytes_start = signable_bytes

    keccak_add_uint256s{inputs=signable_bytes}(n_elements=n_elements + 1, elements=prefixed_uints, bigend=1)

    return keccak_bigend(inputs=signable_bytes_start, n_bytes=n_elements * 32 + 2)
end

func get_keccak_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(uint256_words_len : felt, uint256_words : Uint256*) -> (hash : Uint256):
    alloc_locals

    let (local keccak_ptr : felt*) = alloc()
    let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words)

    return (hash)
end

# will not work for 0
# might need to optimize this?
func get_base16_len{range_check_ptr}(num: Uint256) -> (res: felt):
    let (is_eq) = uint256_eq(num, Uint256(0, 0))
    if is_eq == 1:
        return (0)
    else:
        let (q, _) = uint256_unsigned_div_rem(num, Uint256(16, 0))
        let (res) = get_base16_len(q)
        return (res + 1)
    end
end

func u256_pow{range_check_ptr}(base: Uint256, exp: Uint256) -> (res: Uint256):
    alloc_locals

    let zero = Uint256(0, 0)
    let (exp_is_zero) = uint256_eq(exp, zero)
    if exp_is_zero == 1:
        return (Uint256(1, 0))
    else:
        let (new_exp) = uint256_sub(exp, Uint256(1, 0))
        let (recursion) = u256_pow(base, new_exp)

        let (res, overflow) = uint256_mul(base, recursion)

        with_attr error_message("Overflow happened"):
            let (no_overflow) = uint256_eq(overflow, Uint256(0, 0))
            assert no_overflow = 1
        end

        return (res)
    end
end

func pad_right{range_check_ptr}(num: Uint256) -> (res: Uint256):
    alloc_locals

    let (len_base16) = get_base16_len(num)

    let (_, rem) = unsigned_div_rem(len_base16, 2)
    if rem == 1:
        tempvar len_base16 = len_base16 + 1
    else:
        tempvar len_base16 = len_base16
    end

    # power_16 = 16 ** 64 - len_base16
    let (base) = felt_to_uint256(16)
    let (exp) = felt_to_uint256(64 - len_base16)
    let (power_16) = u256_pow(base, exp)

    let (low, high) = uint256_mul(num, power_16)

    with_attr error_message("overflow?"):
        assert high.low = 0
        assert high.high = 0
    end

    let padded = low

    return (padded)
end

func authenticate_proposal{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(msg_hash: Uint256, r: Uint256, s: Uint256, v: felt, nonce : Uint256, target : felt, calldata_len : felt, calldata : felt*):
    alloc_locals

    # Proposer address should be located in calldata[0]
    let eth_address = calldata[0]

    # execution_hash should be in calldata[2] and calldata[3]
    let execution_hash = Uint256(calldata[1], calldata[2])

    let (padded_execution_hash) = pad_right(execution_hash)

    let (space) = felt_to_uint256(target)

    let (padded_space) = pad_right(space)

    # metadata_uri_len should be in calldata[3]
    # let metadata_uri_len = calldata[3]
    # metadata_uri pointer should be in calldata[5]
    # let metadata_uri = cast(calldata[4], felt*)
    # tempvar a = 3
    # %{ print(f"Printing {ids.a=}") %}

    # now construct the hash
    let (encoded_data: Uint256*) = alloc()

    assert encoded_data[0] = Uint256(PROPOSAL_HASH_LOW, PROPOSAL_HASH_HIGH)
    assert encoded_data[1] = nonce
    assert encoded_data[2] = padded_space
    assert encoded_data[3] = padded_execution_hash

    # This hash is correct
    let (hash_struct) = get_keccak_hash(4, encoded_data)

    let (prepared: Uint256*) = alloc()
    assert prepared[0] = Uint256(DOMAIN_HASH_LOW, DOMAIN_HASH_HIGH)
    assert prepared[1] = hash_struct

    let (local keccak_ptr : felt*) = alloc() 
    let (recovered_hash) = keccak_uint256s_precise_bytes{keccak_ptr=keccak_ptr}(2, prepared)

    let (is_eq) = uint256_eq(recovered_hash, msg_hash)
    with_attr error_message("invalid hash"):
        assert is_eq = 1
    end
    
    let (local keccak_ptr : felt*) = alloc()
    verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(recovered_hash, r, s, v - 27, eth_address)

    #TODO: CALL FINALIZE_KECCAK

    return ()
end

func authenticate_vote{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(nonce : Uint256, target : felt, calldata_len : felt, calldata : felt*):
    with_attr error_message("Voting..."):
        assert 1 = 0
    end
    return ()
end

@external
func authenticate{syscall_ptr : felt*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    msg_hash: Uint256, r: Uint256, s: Uint256, v: felt, nonce : Uint256, target : felt, function_selector : felt, calldata_len : felt, calldata : felt*
) -> ():
    if function_selector == PROPOSAL_SELECTOR:
        authenticate_proposal(msg_hash, r, s, v, nonce, target, calldata_len, calldata)
    else:
        authenticate_vote(nonce, target, calldata_len, calldata)
    end

    with_attr error_message("get rekted"):
        assert 1 = 0
    end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end
