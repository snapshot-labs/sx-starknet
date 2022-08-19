%lang starknet
from contracts.starknet.lib.execute import execute
from contracts.starknet.lib.felt_utils import FeltUtils
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_keccak.keccak import (
    keccak_add_uint256s,
    keccak_bigend,
    finalize_keccak,
)

from contracts.starknet.lib.eth_sig_utils import EthSigUtils

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
    let (space) = FeltUtils.felt_to_uint256(target)
    let (padded_space) = EthSigUtils.pad_right(space)

    # Proposer address
    let (proposer_address_u256) = FeltUtils.felt_to_uint256(proposer_address)
    let (padded_proposer_address) = EthSigUtils.pad_right(proposer_address_u256)

    # Metadata URI
    let metadata_uri_string_len = calldata[1]
    let metadata_uri_len = calldata[2]
    let metadata_uri : felt* = &calldata[3]
    let (metadata_uri_hash) = EthSigUtils.keccak_ints_sequence{keccak_ptr=keccak_ptr}(
        metadata_uri_string_len, metadata_uri_len, metadata_uri
    )

    # Executor
    let executor = calldata[3 + metadata_uri_len]
    let (executor_u256) = FeltUtils.felt_to_uint256(executor)
    let (padded_executor) = EthSigUtils.pad_right(executor_u256)

    # Used voting strategies
    let used_voting_strats_len = calldata[4 + metadata_uri_len]
    let used_voting_strats = &calldata[5 + metadata_uri_len]
    let (used_voting_strategies_hash) = EthSigUtils.get_padded_hash(
        used_voting_strats_len, used_voting_strats
    )

    # User voting strategy params flat
    let user_voting_strat_params_flat_len = calldata[5 + metadata_uri_len + used_voting_strats_len]
    let user_voting_strat_params_flat = &calldata[6 + metadata_uri_len + used_voting_strats_len]
    let (user_voting_strategy_params_flat_hash) = EthSigUtils.get_padded_hash(
        user_voting_strat_params_flat_len, user_voting_strat_params_flat
    )

    # Execution hash
    let execution_params_len = calldata[6 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len]
    let execution_params_ptr : felt* = &calldata[7 + metadata_uri_len + used_voting_strats_len + user_voting_strat_params_flat_len]
    let (execution_hash) = EthSigUtils.get_padded_hash(execution_params_len, execution_params_ptr)

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()

    assert data[0] = Uint256(PROPOSAL_HASH_LOW, PROPOSAL_HASH_HIGH)
    assert data[1] = padded_space
    assert data[2] = padded_proposer_address
    assert data[3] = metadata_uri_hash
    assert data[4] = padded_executor
    assert data[5] = execution_hash
    assert data[6] = used_voting_strategies_hash
    assert data[7] = user_voting_strategy_params_flat_hash
    assert data[8] = salt

    let (hash_struct) = EthSigUtils.get_keccak_hash{keccak_ptr=keccak_ptr}(9, data)

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

    let (space) = FeltUtils.felt_to_uint256(target)
    let (padded_space) = EthSigUtils.pad_right(space)

    let (voter_address_u256) = FeltUtils.felt_to_uint256(voter_address)
    let (padded_voter_address) = EthSigUtils.pad_right(voter_address_u256)

    let (proposal_id) = FeltUtils.felt_to_uint256(calldata[1])
    let (choice) = FeltUtils.felt_to_uint256(calldata[2])

    let used_voting_strategies_len = calldata[3]
    let used_voting_strategies = &calldata[4]
    let (used_voting_strategies_hash) = EthSigUtils.get_padded_hash(
        used_voting_strategies_len, used_voting_strategies
    )

    let user_voting_strategy_params_flat_len = calldata[4 + used_voting_strategies_len]
    let user_voting_strategy_params_flat = &calldata[5 + used_voting_strategies_len]
    let (user_voting_strategy_params_flat_hash) = EthSigUtils.get_padded_hash(
        user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
    )

    # Now construct the data hash (hashStruct)
    let (data : Uint256*) = alloc()
    assert data[0] = Uint256(VOTE_HASH_LOW, VOTE_HASH_HIGH)
    assert data[1] = padded_space
    assert data[2] = padded_voter_address
    assert data[3] = proposal_id
    assert data[4] = choice
    assert data[5] = used_voting_strategies_hash
    assert data[6] = user_voting_strategy_params_flat_hash
    assert data[7] = salt

    let (local keccak_ptr : felt*) = alloc()
    let keccak_ptr_start = keccak_ptr

    let (hash_struct) = EthSigUtils.get_keccak_hash{keccak_ptr=keccak_ptr}(8, data)

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
