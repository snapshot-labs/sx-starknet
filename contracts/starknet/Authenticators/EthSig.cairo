%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_to_uint256 import felt_to_uint256
from contracts.starknet.lib.hash_array import hash_array
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_uint256s_bigend,
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_builtins import HashBuiltin

# TODO maybe use OZ safemath when possible?

# getSelectorFromName("propose")
const PROPOSAL_SELECTOR = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81
# getSelectorFromName("vote")
const VOTE_SELECTOR = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41

const ETHEREUM_PREFIX = 0x1901

# This is the `Proposal` typeHash, obtained by doing this:
# keccak256("Propose(bytes32 space,bytes32 proposerAddress,string metadataUri,bytes32 executor,bytes32 executionParamsHash,bytes32 usedVotingStrategiesHash,bytes32 userVotingStrategyParamsFlatHash,uint256 salt)")
const PROPOSAL_HASH_HIGH = 0xa1a96273f272324c66f87ba1a951949d
const PROPOSAL_HASH_LOW = 0xa34effccf1463302bc6e241f37fe5ef7

# This is the `Vote` typeHash, obtained by doing this:
# keccak256("Vote(bytes32 space,bytes32 voterAddress,uint256 proposal,uint256 choice,bytes32 usedVotingStrategiesHash,bytes32 userVotingStrategyParamsFlatHash,uint256 salt)")
const VOTE_HASH_HIGH = 0x0f76587b41b5c7810a4c8591d4d84385
const VOTE_HASH_LOW = 0x85dba41961e8886710ef5d5cbe72713d

# This is the domainSeparator, obtained by using those fields (see more about it in EIP712):
# name: 'snapshot-x',
# version: '1'
# Which returns: 0x4ea062c13aa1ccc0dde3383926ef913772c5ab51b06b74e448d6b02ce79ba93c
const DOMAIN_HASH_HIGH = 0x4ea062c13aa1ccc0dde3383926ef9137
const DOMAIN_HASH_LOW = 0x72c5ab51b06b74e448d6b02ce79ba93c

# Maps a tuple of (user, salt) to a boolean stating whether this tuple was already used or not (to prevent replay attack).
@storage_var
func salts(user : felt, salt : Uint256) -> (already_used : felt):
end

# Adds a 2 bytes (16 bits) `prefix` to a 16 bytes (128 bits) `value`.
func add_prefix128{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(value : felt, prefix : felt) -> (
    result : felt, carry
):
    # Shift the prefix by 128 bits
    let shifted_prefix = prefix * 2 ** 128
    # `with_prefix` is now 18 bytes long
    let with_prefix = shifted_prefix + value
    # Create 2 bytes mask
    let overflow_mask = 2 ** 16 - 1
    # Extract the last two bytes of `with_prefix`
    let (carry) = bitwise_and(with_prefix, overflow_mask)
    # Compute the new number, right shift by 16
    let result = (with_prefix - carry) / 2 ** 16
    return (result, carry)
end

# Concatenates a 2 bytes long `prefix` and `input` to `output`.
# `input_len` is the number of `Uint256` in `input`.
func prepend_prefix_2bytes{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(
    prefix : felt, output : Uint256*, input_len : felt, input : Uint256*
):
    if input_len == 0:
        # Done, simlpy store the prefix in the `.high` part of the last Uint256, and
        # make sure we left shift it by 28 (32 - 4)
        assert output[0] = Uint256(0, prefix * 16 ** 28)
        return ()
    else:
        let num = input[0]

        let (w1, high_carry) = add_prefix128(num.high, prefix)
        let (w0, low_carry) = add_prefix128(num.low, high_carry)

        let res = Uint256(w0, w1)
        assert output[0] = res

        # Recurse, using the `low_carry` as `prefix`
        prepend_prefix_2bytes(low_carry, &output[1], input_len - 1, &input[1])
        return ()
    end
end

# Computes the `keccak256` hash from an array of `Uint256`. Does NOT call `finalize_keccak`,
# so the caller needs to make she calls `finalize_keccak` on the `keccak_ptr` once she's done
# with it.
func get_keccak_hash{range_check_ptr, bitwise_ptr : BitwiseBuiltin*, keccak_ptr : felt*}(
    uint256_words_len : felt, uint256_words : Uint256*
) -> (hash : Uint256):
    let (hash) = keccak_uint256s_bigend{keccak_ptr=keccak_ptr}(uint256_words_len, uint256_words)

    return (hash)
end

# Returns the number of digits needed to represent `num` in hexadecimal.
# Similar to doing `len(hex(num)[2:])` in Python.
# E.g.:
# - `0x123` will return `3`
# - `0x1` will return `1`
# - `0xa3b1d4` will return `6`
# Notice: Will not work for `0x0` (will return `0` for `0x0` instead of `1`).
func get_base16_len{range_check_ptr}(num : Uint256) -> (res : felt):
    let (is_eq) = uint256_eq(num, Uint256(0, 0))
    if is_eq == 1:
        return (0)
    else:
        # Divide by 16
        let (divided, _) = uint256_unsigned_div_rem(num, Uint256(16, 0))

        let (res_len) = get_base16_len(divided)
        return (res_len + 1)
    end
end

# Computes `base ** exp` where `base` and `exp` are both `felts` and returns the result as a `Uint256`.
func u256_pow{range_check_ptr}(base : felt, exp : felt) -> (res : Uint256):
    alloc_locals

    if exp == 0:
        # Any number to the power of 0 is 1
        return (Uint256(1, 0))
    else:
        # Compute `base ** exp - 1`
        let (recursion) = u256_pow(base, exp - 1)

        let (uint256_base) = felt_to_uint256(base)

        # Multiply the result by `base`
        let (res, overflow) = uint256_mul(recursion, uint256_base)

        with_attr error_message("Overflow happened"):
            let (no_overflow) = uint256_eq(overflow, Uint256(0, 0))
            assert no_overflow = 1
        end

        return (res)
    end
end

# Right pads `num` with `0` to make it 32 bytes long.
# E.g:
# - right_pad(0x1)  -> (0x0100000000000000000000000000000000000000000000000000000000000000)
# - right_pad(0xaa) -> (0xaa00000000000000000000000000000000000000000000000000000000000000)
func pad_right{range_check_ptr}(num : Uint256) -> (res : Uint256):
    let (len_base16) = get_base16_len(num)

    let (_, rem) = unsigned_div_rem(len_base16, 2)
    if rem == 1:
        # Odd-length: add one (a byte is two characters long)
        tempvar len_base16 = len_base16 + 1
    else:
        tempvar len_base16 = len_base16
    end

    let base = 16
    let exp = 64 - len_base16
    let (power_16) = u256_pow(base, exp)

    # Left shift
    let (low, high) = uint256_mul(num, power_16)

    with_attr error_message("overflow?"):
        assert high.low = 0
        assert high.high = 0
    end

    return (low)
end

func keccak_ints_sequence{range_check_ptr, bitwise_ptr : BitwiseBuiltin*, keccak_ptr : felt*}(
    nb_bytes : felt, sequence_len : felt, sequence : felt*
) -> (res : Uint256):
    return keccak_bigend(inputs=sequence, n_bytes=nb_bytes)
end

func get_padded_hash{range_check_ptr, pedersen_ptr : HashBuiltin*}(input_len: felt, input: felt*) -> (res: Uint256):
    alloc_locals

    let (hash) = hash_array(input_len, input)
    let (hash_u256) = felt_to_uint256(hash)
    let (padded_hash) = pad_right(hash_u256)

    return (res=padded_hash)
end

@external
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

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr

    # Space address
    let (space) = felt_to_uint256(target)
    let (padded_space) = pad_right(space)

    # Proposer address
    let (proposer_address_u256) = felt_to_uint256(proposer_address)
    let (padded_proposer_address) = pad_right(proposer_address_u256)

    # Metadata URI
    let metadata_uri_string_len = calldata[1]
    let metadata_uri_len = calldata[2]
    let metadata_uri : felt* = &calldata[3]
    let (metadata_uri_hash) = keccak_ints_sequence{keccak_ptr=keccak_ptr}(
        metadata_uri_string_len, metadata_uri_len, metadata_uri
    )

    # Executor
    let executor = calldata[3 + metadata_uri_len]
    let (executor_u256) = felt_to_uint256(executor)
    let (padded_executor) = pad_right(executor_u256)

    # Used voting strategies
    let used_voting_strats_len = calldata[4 + metadata_uri_len]
    let used_voting_strats = &calldata[5 + metadata_uri_len]
    let (used_voting_strategies_hash) = hash_array(used_voting_strats_len, used_voting_strats)
    let (used_voting_strategies_hash_u256) = felt_to_uint256(used_voting_strategies_hash)
    let (padded_used_voting_strategies_hash) = pad_right(used_voting_strategies_hash_u256)

    # User voting strategy params flat
    let user_voting_strat_params_flat_len = calldata[5 + metadata_uri_len + used_voting_strats_len]
    let user_voting_strat_params_flat = &calldata[6 + metadata_uri_len + used_voting_strats_len]
    let (user_voting_strat_params_flat_hash) = hash_array(
        user_voting_strat_params_flat_len, user_voting_strat_params_flat
    )
    let (user_voting_strat_params_flat_hash_u256) = felt_to_uint256(
        user_voting_strat_params_flat_hash
    )
    let (padded_user_voting_strategy_params_flat_hash) = pad_right(
        user_voting_strat_params_flat_hash_u256
    )

    # Execution hash
    let execution_params_len = calldata[6 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len]
    let execution_params_ptr : felt* = &calldata[7 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len]
    let (execution_hash) = hash_array(execution_params_len, execution_params_ptr)
    let (exec_hash_u256) = felt_to_uint256(execution_hash)
    let (padded_execution_hash) = pad_right(exec_hash_u256)

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()

    assert data[0] = Uint256(PROPOSAL_HASH_LOW, PROPOSAL_HASH_HIGH)
    assert data[1] = padded_space
    assert data[2] = padded_proposer_address
    assert data[3] = metadata_uri_hash
    assert data[4] = padded_executor
    assert data[5] = padded_execution_hash
    assert data[6] = padded_used_voting_strategies_hash
    assert data[7] = padded_user_voting_strategy_params_flat_hash
    assert data[8] = salt

    let (hash_struct) = get_keccak_hash{keccak_ptr=keccak_ptr}(9, data)

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

@external
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

    let voter_address = calldata[0]

    # Ensure voter has not already used this salt in a previous action
    let (already_used) = salts.read(voter_address, salt)

    with_attr error_message("Salt already used"):
        assert already_used = 0
    end

    let (space) = felt_to_uint256(target)
    let (padded_space) = pad_right(space)

    let (voter_address_u256) = felt_to_uint256(voter_address)
    let (padded_voter_address) = pad_right(voter_address_u256)

    let (proposal_id) = felt_to_uint256(calldata[1])
    let (choice) = felt_to_uint256(calldata[2])

    let used_voting_strategies_len = calldata[3]
    let used_voting_strategies = &calldata[4]
    let (used_voting_strategies_hash) = hash_array(
        used_voting_strategies_len, used_voting_strategies
    )
    let (used_voting_strategies_hash_u256) = felt_to_uint256(used_voting_strategies_hash)
    let (padded_used_voting_strategies_hash) = pad_right(used_voting_strategies_hash_u256)

    let user_voting_strategy_params_flat_len = calldata[4 + used_voting_strategies_len]
    let user_voting_strategy_params_flat = &calldata[5 + used_voting_strategies_len]
    let (user_voting_strategy_params_flat_hash) = hash_array(
        user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
    )
    let (user_voting_strategy_params_flat_hash_u256) = felt_to_uint256(
        user_voting_strategy_params_flat_hash
    )
    let (padded_user_voting_strategy_params_flat_hash) = pad_right(
        user_voting_strategy_params_flat_hash_u256
    )

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()
    assert data[0] = Uint256(VOTE_HASH_LOW, VOTE_HASH_HIGH)
    assert data[1] = padded_space
    assert data[2] = padded_voter_address
    assert data[3] = proposal_id
    assert data[4] = choice
    assert data[5] = padded_used_voting_strategies_hash
    assert data[6] = padded_user_voting_strategy_params_flat_hash
    assert data[7] = salt

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr

    let (hash_struct) = get_keccak_hash{keccak_ptr=keccak_ptr}(8, data)

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
        if function_selector == VOTE_SELECTOR:
            authenticate_vote(r, s, v, salt, target, calldata_len, calldata)
        else:
            # Invalid selector
            return ()
        end
    end

    # Call the contract
    execute(target, function_selector, calldata_len, calldata)

    return ()
end
