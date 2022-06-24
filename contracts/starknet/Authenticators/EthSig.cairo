%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
    uint256_sub,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_uint256s_bigend,
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.pow import pow
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.cairo_builtins import HashBuiltin

# TODO maybe use OZ safemath when possible?

# getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81
# getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41

const BYTES_IN_UINT256 = 32

const ETHEREUM_PREFIX = 0x1901

# TYPEHASH
# keccak256("Propose(uint256 salt,bytes32 space,bytes32 executionHash)")
# 0x54c098ca8d69ef660ee5f92f559d202640122887e093031aaa36b4066a50c624
const PROPOSAL_HASH_HIGH = 0x54c098ca8d69ef660ee5f92f559d2026
const PROPOSAL_HASH_LOW = 0x40122887e093031aaa36b4066a50c624

# keccak256("Vote(uint256 salt,bytes32 space,uint256 proposal,uint256 choice)")
# 0x0a2717ddf197067ae85a6f41872b66f70cfba68208c9e9e5e5121904e822fc51
const VOTE_HASH_HIGH = 0x0a2717ddf197067ae85a6f41872b66f7
const VOTE_HASH_LOW = 0x0cfba68208c9e9e5e5121904e822fc51

# DOMAIN HASH
# name: 'snapshot-x',
# version: '1'
# 0x4ea062c13aa1ccc0dde3383926ef913772c5ab51b06b74e448d6b02ce79ba93c
const DOMAIN_HASH_HIGH = 0x4ea062c13aa1ccc0dde3383926ef9137
const DOMAIN_HASH_LOW = 0x72c5ab51b06b74e448d6b02ce79ba93c

@storage_var
func salts(user : felt, salt : Uint256) -> (already_used : felt):
end

# value has to be a 16 byte word
# prefix length = PREFIX_BITS
func add_prefix128{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(value : felt, prefix : felt) -> (
    result : felt, overflow
):
    let shifted_prefix = prefix * 2 ** 128
    # with_prefix is 18 bytes long
    let with_prefix = shifted_prefix + value
    let overflow_mask = 2 ** 16 - 1
    let (overflow) = bitwise_and(with_prefix, overflow_mask)
    let result = (with_prefix - overflow) / 2 ** 16
    return (result, overflow)
end

func prepend_prefix_2bytes{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    prefix : felt, output : Uint256*, input_len : felt, input : Uint256*
):
    if input_len == 0:
        assert output[0] = Uint256(0, prefix * 16 ** 28)
        return ()
    else:
        let num = input[0]
        let (w1, prefix) = add_prefix128(num.high, prefix)
        let (w0, prefix) = add_prefix128(num.low, prefix)

        let res = Uint256(w0, w1)
        assert output[0] = res

        prepend_prefix_2bytes(prefix, &output[1], input_len - 1, &input[1])
        return ()
    end
end

func get_keccak_hash{range_check_ptr, bitwise_ptr : BitwiseBuiltin*, keccak_ptr : felt*}(
    uint256_words_len : felt, uint256_words : Uint256*
) -> (hash : Uint256):
    alloc_locals

    let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words)

    return (hash)
end

# will not work for 0
# might need to optimize this?
func get_base16_len{range_check_ptr}(num : Uint256) -> (res : felt):
    let (is_eq) = uint256_eq(num, Uint256(0, 0))
    if is_eq == 1:
        return (0)
    else:
        let (q, _) = uint256_unsigned_div_rem(num, Uint256(16, 0))
        let (res) = get_base16_len(q)
        return (res + 1)
    end
end

func u256_pow{range_check_ptr}(base : Uint256, exp : Uint256) -> (res : Uint256):
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

func pad_right{range_check_ptr}(num : Uint256) -> (res : Uint256):
    alloc_locals

    let (len_base16) = get_base16_len(num)

    let (_, rem) = unsigned_div_rem(len_base16, 2)
    if rem == 1:
        tempvar len_base16 = len_base16 + 1
    else:
        tempvar len_base16 = len_base16
    end

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

func authenticate_proposal{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(
    r : Uint256,
    s : Uint256,
    v : felt,
    salt : Uint256,
    target : felt,
    calldata_len : felt,
    calldata : felt*,
):
    alloc_locals

    # Proposer address should be located in calldata[0]
    let proposer_address = calldata[0]

    # Ensure proposer has not already used this salt in a previous action
    let (already_used) = salts.read(proposer_address, salt)

    with_attr error_message("Salt already used"):
        assert already_used = 0
    end

    # Execution_hash should be in calldata[1] and calldata[2]
    let execution_hash = Uint256(calldata[1], calldata[2])

    # `bytes32` types need to be right padded
    let (padded_execution_hash) = pad_right(execution_hash)

    let (space) = felt_to_uint256(target)
    # `bytes32` types need to be right padded
    let (padded_space) = pad_right(space)

    # metadata_uri_len should be in calldata[3]
    # let metadata_uri_len = calldata[3]
    # metadata_uri pointer should be in calldata[4]
    # let metadata_uri = cast(calldata[4], felt*)

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()

    assert data[0] = Uint256(PROPOSAL_HASH_LOW, PROPOSAL_HASH_HIGH)
    assert data[1] = salt
    assert data[2] = padded_space
    assert data[3] = padded_execution_hash

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr

    let (hash_struct) = get_keccak_hash{keccak_ptr=keccak_ptr}(4, data)

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

    # `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
    # We substract `27` because `v` = `{0, 1} + 27`
    verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(hash, r, s, v - 27, proposer_address)

    # Verify that all the previous keccaks are correct
    finalize_keccak(keccak_ptr_start, keccak_ptr)

    # Write the salt to prevent replay attack
    salts.write(proposer_address, salt, 1)

    return ()
end

func authenticate_vote{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(
    r : Uint256,
    s : Uint256,
    v : felt,
    salt : Uint256,
    target : felt,
    calldata_len : felt,
    calldata : felt*,
):
    alloc_locals

    # Voter address should be located in calldata[0]
    let voter_address = calldata[0]

    # Ensure voter has not already used this salt in a previous action
    let (already_used) = salts.read(voter_address, salt)

    with_attr error_message("Salt already used"):
        assert already_used = 0
    end

    let (space) = felt_to_uint256(target)
    # `bytes32` types need to be right padded
    let (padded_space) = pad_right(space)
    let (proposal_id) = felt_to_uint256(calldata[1])
    let (choice) = felt_to_uint256(calldata[2])

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()

    assert data[0] = Uint256(VOTE_HASH_LOW, VOTE_HASH_HIGH)
    assert data[1] = salt
    assert data[2] = padded_space
    assert data[3] = proposal_id
    assert data[4] = choice

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr

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

    # `v` is supposed to be `yParity` and not the `v` usually used in the Ethereum world (pre-EIP155).
    # We substract `27` because `v` = `{0, 1} + 27`
    verify_eth_signature_uint256{keccak_ptr=keccak_ptr}(hash, r, s, v - 27, voter_address)

    # Verify that all the previous keccaks are correct
    finalize_keccak(keccak_ptr_start, keccak_ptr)

    # Write the salt to prevent replay attack
    salts.write(voter_address, salt, 1)

    return ()
end

@external
func authenticate{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(
    r : Uint256,
    s : Uint256,
    v : felt,
    salt : Uint256,
    target : felt,
    function_selector : felt,
    calldata_len : felt,
    calldata : felt*,
) -> ():
    if function_selector == PROPOSAL_SELECTOR:
        authenticate_proposal(r, s, v, salt, target, calldata_len, calldata)
    else:
        authenticate_vote(r, s, v, salt, target, calldata_len, calldata)
    end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end
