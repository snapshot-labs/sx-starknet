// SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_tx_info
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt, uint256_le, uint256_eq
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_lt, assert_le, assert_nn, assert_not_zero

from openzeppelin.account.library import Account, AccountCallArray, Call
from openzeppelin.security.safemath.library import SafeUint256

from contracts.starknet.Interfaces.IVotingStrategy import IVotingStrategy
from contracts.starknet.Interfaces.IExecutionStrategy import IExecutionStrategy
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.proposal import Proposal
from contracts.starknet.lib.proposal_info import ProposalInfo
from contracts.starknet.lib.vote import Vote
from contracts.starknet.lib.choice import Choice
from contracts.starknet.lib.proposal_outcome import ProposalOutcome
from contracts.starknet.lib.array_utils import ArrayUtils, Immutable2DArray
from contracts.starknet.lib.math_utils import MathUtils

//
// @title Snapshot X Voting Library
// @author SnapshotLabs
// @notice Library that implements the core functionality of Snapshot X
//

//
// Storage
//

@storage_var
func Voting_voting_delay_store() -> (delay: felt) {
}

@storage_var
func Voting_min_voting_duration_store() -> (period: felt) {
}

@storage_var
func Voting_max_voting_duration_store() -> (period: felt) {
}

@storage_var
func Voting_proposal_threshold_store() -> (threshold: Uint256) {
}

@storage_var
func Voting_quorum_store() -> (value: Uint256) {
}

@storage_var
func Voting_authenticators_store(authenticator_address: felt) -> (is_valid: felt) {
}

@storage_var
func Voting_execution_strategies_store(execution_strategy_address: felt) -> (is_valid: felt) {
}

@storage_var
func Voting_voting_strategies_store(strategy_index: felt) -> (strategy_address: felt) {
}

@storage_var
func Voting_num_voting_strategies_store() -> (num: felt) {
}

@storage_var
func Voting_voting_strategy_params_store(strategy_index: felt, param_index: felt) -> (param: felt) {
}

@storage_var
func Voting_next_proposal_nonce_store() -> (nonce: felt) {
}

@storage_var
func Voting_proposal_registry_store(proposal_id: felt) -> (proposal: Proposal) {
}

@storage_var
func Voting_executed_proposals_store(proposal_id: felt) -> (executed: felt) {
}

@storage_var
func Voting_vote_registry_store(proposal_id: felt, voter_address: Address) -> (voted: felt) {
}

@storage_var
func Voting_vote_power_store(proposal_id: felt, choice: felt) -> (power: Uint256) {
}

//
// Events
//

@event
func proposal_created(
    proposal_id: felt,
    proposer_address: Address,
    proposal: Proposal,
    metadata_uri_len: felt,
    metadata_uri: felt*,
    execution_params_len: felt,
    execution_params: felt*,
) {
}

@event
func proposal_finalized(proposal_id: felt, outcome: felt) {
}

@event
func vote_created(proposal_id: felt, voter_address: Address, vote: Vote) {
}

@event
func quorum_updated(previous: Uint256, new_quorum: Uint256) {
}

@event
func voting_delay_updated(previous: felt, new_voting_delay: felt) {
}

@event
func min_voting_duration_updated(previous: felt, new_voting_duration: felt) {
}

@event
func max_voting_duration_updated(previous: felt, new_voting_duration: felt) {
}

@event
func proposal_threshold_updated(previous: Uint256, new_proposal_threshold: Uint256) {
}

@event
func metadata_uri_updated(new_metadata_uri_len: felt, new_metadata_uri: felt*) {
}

@event
func authenticators_added(added_len: felt, added: felt*) {
}

@event
func authenticators_removed(removed_len: felt, removed: felt*) {
}

@event
func execution_strategies_added(added_len: felt, added: felt*) {
}

@event
func execution_strategies_removed(removed_len: felt, removed: felt*) {
}

@event
func voting_strategies_added(added_len: felt, added: felt*) {
}

@event
func voting_strategies_removed(removed_len: felt, removed: felt*) {
}

namespace Voting {
    // @dev Initializes the library, must be called in the constructor of contracts that use the library
    // @param voting_delay The delay between when a proposal is created, and when the voting starts
    // @param min_voting_duration The minimum duration of the voting period
    // @param max_voting_duration The maximum duration of the voting period
    // @param proposal_threshold The minimum amount of voting power needed to be able to create a new proposal in the space
    // @param quorum The minimum total voting power required for a proposal to pass
    // @param voting_strategies Array of whitelisted voting strategy contract addresses
    // @param voting_strategy_params_flat Flattened 2D array of voting strategy parameters
    // @param authenticators Array of whitelisted authenticator contract addresses
    // @param execution_strategies Array of whitelisted execution strategy contract addresses
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        voting_delay: felt,
        min_voting_duration: felt,
        max_voting_duration: felt,
        proposal_threshold: Uint256,
        quorum: Uint256,
        voting_strategies_len: felt,
        voting_strategies: felt*,
        voting_strategy_params_flat_len: felt,
        voting_strategy_params_flat: felt*,
        authenticators_len: felt,
        authenticators: felt*,
        execution_strategies_len: felt,
        execution_strategies: felt*,
    ) {
        alloc_locals;

        with_attr error_message("Voting: Invalid constructor parameters") {
            assert_nn(voting_delay);
            assert_le(min_voting_duration, max_voting_duration);
            assert_not_zero(voting_strategies_len);
            assert_not_zero(authenticators_len);
            assert_not_zero(execution_strategies_len);
            MathUtils.assert_valid_uint256(proposal_threshold);
            MathUtils.assert_valid_uint256(quorum);
        }

        // Initialize the storage variables
        Voting_voting_delay_store.write(voting_delay);
        Voting_min_voting_duration_store.write(min_voting_duration);
        Voting_max_voting_duration_store.write(max_voting_duration);
        Voting_proposal_threshold_store.write(proposal_threshold);
        Voting_quorum_store.write(quorum);

        // Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        // Currently there is no way to pass struct types with pointers in calldata, so we must do it this way.
        let (voting_strategy_params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            voting_strategy_params_flat_len, voting_strategy_params_flat
        );

        _unchecked_add_voting_strategies(
            voting_strategies_len, voting_strategies, voting_strategy_params_all
        );
        _unchecked_add_authenticators(authenticators_len, authenticators);
        _unchecked_add_execution_strategies(execution_strategies_len, execution_strategies);

        // The first proposal in a space will have a proposal ID of 1.
        Voting_next_proposal_nonce_store.write(1);

        return ();
    }

    // @dev Updates the quorum
    // @param new_quorum The new quorum
    func update_quorum{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        new_quorum: Uint256
    ) {
        MathUtils.assert_valid_uint256(new_quorum);
        let (previous_quorum) = Voting_quorum_store.read();
        Voting_quorum_store.write(new_quorum);
        quorum_updated.emit(previous_quorum, new_quorum);
        return ();
    }

    // @dev Updates the voting delay
    // @param new_voting_delay The new voting delay
    func update_voting_delay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        new_voting_delay: felt
    ) {
        let (previous_delay) = Voting_voting_delay_store.read();
        Voting_voting_delay_store.write(new_voting_delay);
        voting_delay_updated.emit(previous_delay, new_voting_delay);
        return ();
    }

    // @dev Updates the minimum voting duration
    // @param new_min_voting_duration The new minimum voting duration
    func update_min_voting_duration{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(new_min_voting_duration: felt) {
        let (previous_min_voting_duration) = Voting_min_voting_duration_store.read();
        let (max_voting_duration) = Voting_max_voting_duration_store.read();
        with_attr error_message(
                "Voting: Min voting duration must be less than max voting duration") {
            assert_le(new_min_voting_duration, max_voting_duration);
        }
        Voting_min_voting_duration_store.write(new_min_voting_duration);
        min_voting_duration_updated.emit(previous_min_voting_duration, new_min_voting_duration);
        return ();
    }

    // @dev Updates the maximum voting duration
    // @param new_max_voting_duration The new maximum voting duration
    func update_max_voting_duration{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(new_max_voting_duration: felt) {
        let (previous_max_voting_duration) = Voting_max_voting_duration_store.read();
        let (min_voting_duration) = Voting_min_voting_duration_store.read();
        with_attr error_message(
                "Voting: Max voting duration must be greater than min voting duration") {
            assert_le(min_voting_duration, new_max_voting_duration);
        }
        Voting_max_voting_duration_store.write(new_max_voting_duration);
        max_voting_duration_updated.emit(previous_max_voting_duration, new_max_voting_duration);
        return ();
    }

    // @dev Updates the proposal threshold
    // @param new_proposal_threshold The new proposal threshold
    func update_proposal_threshold{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(new_proposal_threshold: Uint256) {
        MathUtils.assert_valid_uint256(new_proposal_threshold);
        let (previous_proposal_threshold) = Voting_proposal_threshold_store.read();
        Voting_proposal_threshold_store.write(new_proposal_threshold);
        proposal_threshold_updated.emit(previous_proposal_threshold, new_proposal_threshold);
        return ();
    }

    // @dev Updates the metadata URI
    // @param new_metadata_uri The new metadata URI
    // @notice We do not store the metadata URI in the contract state, it is just emitted as an event which allows it to be picked up by an indexer
    func update_metadata_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        new_metadata_uri_len: felt, new_metadata_uri: felt*
    ) {
        alloc_locals;
        metadata_uri_updated.emit(new_metadata_uri_len, new_metadata_uri);
        return ();
    }

    // @dev Adds execution strategy contracts to the whitelist
    // @param addresses Array of execution strategy contract addresses
    func add_execution_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*) {
        alloc_locals;
        _unchecked_add_execution_strategies(addresses_len, addresses);
        execution_strategies_added.emit(addresses_len, addresses);
        return ();
    }

    // @dev Removes execution strategy contracts from the whitelist
    // @param addresses Array of execution strategy contract addresses
    func remove_execution_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*) {
        alloc_locals;
        _unchecked_remove_execution_strategies(addresses_len, addresses);
        execution_strategies_removed.emit(addresses_len, addresses);
        return ();
    }

    // @dev Adds voting strategy contracts to the whitelist
    // @param addresses Array of voting strategy contract addresses
    // @param params_flat Flattened 2D array of voting strategy parameters
    func add_voting_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*, params_flat_len: felt, params_flat: felt*) {
        alloc_locals;
        _assert_no_active_proposal();
        let (params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            params_flat_len, params_flat
        );
        _unchecked_add_voting_strategies(addresses_len, addresses, params_all);
        voting_strategies_added.emit(addresses_len, addresses);
        return ();
    }

    // @dev Removes voting strategy contracts from the whitelist
    // @param indexes Array of voting strategy indexes to remove
    func remove_voting_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(indexes_len: felt, indexes: felt*) {
        alloc_locals;
        _assert_no_active_proposal();
        _unchecked_remove_voting_strategies(indexes_len, indexes);
        voting_strategies_removed.emit(indexes_len, indexes);
        return ();
    }

    // @dev Adds authenticator contracts to the whitelist
    // @param addresses Array of authenticator contract addresses
    func add_authenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        addresses_len: felt, addresses: felt*
    ) {
        alloc_locals;
        _assert_no_active_proposal();
        _unchecked_add_authenticators(addresses_len, addresses);
        authenticators_added.emit(addresses_len, addresses);
        return ();
    }

    // @dev Removes authenticator contracts from the whitelist
    // @param addresses Array of authenticator contract addresses
    func remove_authenticators{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*) {
        alloc_locals;
        _assert_no_active_proposal();
        _unchecked_remove_authenticators(addresses_len, addresses);
        authenticators_removed.emit(addresses_len, addresses);
        return ();
    }

    // @dev Casts a vote on a proposal
    // @param voter_address The address of the voter
    // @param proposal_id The ID of the proposal in the space
    // @param choice The voter's choice (FOR, AGAINST, ABSTAIN)
    // @used_voting_strategies The voting strategies (within the whitelist for the space) that the voter has non-zero voting power with
    // @user_voting_strategy_params_flat Flattened 2D array of parameters for the voting strategies used
    func vote{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr: felt,
    }(
        voter_address: Address,
        proposal_id: felt,
        choice: felt,
        used_voting_strategies_len: felt,
        used_voting_strategies: felt*,
        user_voting_strategy_params_flat_len: felt,
        user_voting_strategy_params_flat: felt*,
    ) -> () {
        alloc_locals;

        // Verify that the caller is the authenticator contract.
        _assert_valid_authenticator();

        // Make sure proposal has not already been executed
        with_attr error_message("Voting: Proposal already executed") {
            let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);
            assert has_been_executed = 0;
        }

        let (proposal) = Voting_proposal_registry_store.read(proposal_id);

        // Unpacking the timestamps from the packed value
        let (
            snapshot_timestamp, start_timestamp, min_end_timestamp, max_end_timestamp
        ) = MathUtils.unpack_4_32_bit(proposal.timestamps);

        with_attr error_message("Voting: Proposal does not exist") {
            // Asserting start timestamp is not zero because start timestamp
            // is necessarily > 0 when creating a new proposal.
            assert_not_zero(start_timestamp);
        }

        let (current_timestamp) = get_block_timestamp();
        // Make sure proposal is still open for voting
        with_attr error_message("Voting: Voting period has ended") {
            assert_lt(current_timestamp, max_end_timestamp);
        }

        // Make sure proposal has started
        with_attr error_message("Voting: Voting has not started yet") {
            assert_le(start_timestamp, current_timestamp);
        }

        // Make sure voter has not already voted
        let (prev_vote) = Voting_vote_registry_store.read(proposal_id, voter_address);
        with_attr error_message("Voting: User already voted") {
            assert prev_vote = 0;
        }

        // Make sure `choice` is a valid choice
        with_attr error_message("Voting: Invalid choice") {
            assert (choice - Choice.ABSTAIN) * (choice - Choice.FOR) * (choice - Choice.AGAINST) = 0;
        }

        // Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        let (user_voting_strategy_params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        );

        let (user_voting_power) = _get_cumulative_voting_power(
            snapshot_timestamp,
            voter_address,
            used_voting_strategies_len,
            used_voting_strategies,
            user_voting_strategy_params_all,
            0,
        );

        let (no_voting_power) = uint256_eq(Uint256(0, 0), user_voting_power);
        with_attr error_message("Voting: No voting power for user") {
            assert no_voting_power = 0;
        }

        let (previous_voting_power) = Voting_vote_power_store.read(proposal_id, choice);
        with_attr error_message("Voting: Overflow in voting power") {
            let (new_voting_power) = SafeUint256.add(user_voting_power, previous_voting_power);
        }

        Voting_vote_power_store.write(proposal_id, choice, new_voting_power);
        Voting_vote_registry_store.write(proposal_id, voter_address, 1);

        // Emit event
        let vote = Vote(choice=choice, voting_power=user_voting_power);
        vote_created.emit(proposal_id, voter_address, vote);

        return ();
    }

    // @dev Creates a proposal
    // @param proposer_address The address of the proposal creator
    // @param metadata_uri_string_len The string length of the metadata URI (required for keccak hashing)
    // @param metadata_uri The metadata URI for the proposal
    // @param used_voting_strategies The voting strategies (within the whitelist for the space) that the proposal creator has non-zero voting power with
    // @param user_voting_strategy_params_flat Flattened 2D array of parameters for the voting strategies used
    // @param execution_params Execution parameters for the proposal
    func propose{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposer_address: Address,
        metadata_uri_string_len: felt,
        metadata_uri_len: felt,
        metadata_uri: felt*,
        execution_strategy: felt,
        used_voting_strategies_len: felt,
        used_voting_strategies: felt*,
        user_voting_strategy_params_flat_len: felt,
        user_voting_strategy_params_flat: felt*,
        execution_params_len: felt,
        execution_params: felt*,
    ) -> () {
        alloc_locals;

        // Verify that the caller is the authenticator contract.
        _assert_valid_authenticator();

        // Verify that the execution strategy address is one of the whitelisted addresses
        _assert_valid_execution_strategy(execution_strategy);

        // The snapshot for the proposal is the current timestamp at proposal creation
        // We use a timestamp instead of a block number to define a snapshot so that the system can generalize to multi-chain
        // TODO: Need to consider what sort of guarantees we have on the timestamp returned being correct.
        let (snapshot_timestamp) = get_block_timestamp();
        let (delay) = Voting_voting_delay_store.read();

        let (min_voting_duration) = Voting_min_voting_duration_store.read();
        let (max_voting_duration) = Voting_max_voting_duration_store.read();

        // Define start_timestamp, min_end and max_end
        let start_timestamp = snapshot_timestamp + delay;
        let min_end_timestamp = start_timestamp + min_voting_duration;
        let max_end_timestamp = start_timestamp + max_voting_duration;

        // Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        let (user_voting_strategy_params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        );

        let (voting_power) = _get_cumulative_voting_power(
            snapshot_timestamp,
            proposer_address,
            used_voting_strategies_len,
            used_voting_strategies,
            user_voting_strategy_params_all,
            0,
        );

        // Verify that the proposer has enough voting power to trigger a proposal
        let (threshold) = Voting_proposal_threshold_store.read();
        let (has_enough_vp) = uint256_le(threshold, voting_power);
        with_attr error_message("Voting: Not enough voting power") {
            assert has_enough_vp = 1;
        }

        // Hash the execution params
        // Storing arrays inside a struct is impossible so instead we just store a hash and then reconstruct the array in finalize_proposal
        let (execution_hash) = ArrayUtils.hash(execution_params_len, execution_params);

        let (quorum) = Voting_quorum_store.read();

        // Packing the timestamps into a single felt to reduce storage usage
        let (packed_timestamps) = MathUtils.pack_4_32_bit(
            snapshot_timestamp, start_timestamp, min_end_timestamp, max_end_timestamp
        );

        // Create the proposal and its proposal id
        let proposal = Proposal(quorum, packed_timestamps, execution_strategy, execution_hash);

        let (proposal_id) = Voting_next_proposal_nonce_store.read();

        // Store the proposal
        Voting_proposal_registry_store.write(proposal_id, proposal);

        // Emit event
        proposal_created.emit(
            proposal_id,
            proposer_address,
            proposal,
            metadata_uri_len,
            metadata_uri,
            execution_params_len,
            execution_params,
        );

        // Increase the proposal nonce
        Voting_next_proposal_nonce_store.write(proposal_id + 1);

        return ();
    }

    // @dev Finalizes a proposal, triggering execution via the chosen execution strategy
    // @param proposal_id The ID of the proposal
    // @param execution_params Execution parameters for the proposal (must be the same as those submitted during proposal creation)
    @external
    func finalize_proposal{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
    }(proposal_id: felt, execution_params_len: felt, execution_params: felt*) {
        alloc_locals;

        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);

        // Make sure proposal has not already been executed
        with_attr error_message("Voting: Proposal already executed") {
            assert has_been_executed = 0;
        }

        let (proposal) = Voting_proposal_registry_store.read(proposal_id);

        // Unpacking the the timestamps from the packed value
        let (
            snapshot_timestamp, start_timestamp, min_end_timestamp, max_end_timestamp
        ) = MathUtils.unpack_4_32_bit(proposal.timestamps);

        with_attr error_message("Voting: Invalid proposal id") {
            // Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
            // be set to 0, hence the snapshot timestamp will be set to 0 too.
            assert_not_zero(snapshot_timestamp);
        }

        // Make sure proposal period has ended
        let (current_timestamp) = get_block_timestamp();
        with_attr error_message("Voting: Min voting period has not elapsed") {
            assert_le(min_end_timestamp, current_timestamp);
        }

        // Make sure execution params match the ones sent at proposal creation by checking that the hashes match
        let (recovered_hash) = ArrayUtils.hash(execution_params_len, execution_params);
        with_attr error_message("Voting: Invalid execution parameters") {
            assert recovered_hash = proposal.execution_hash;
        }

        // Count votes for
        let (for) = Voting_vote_power_store.read(proposal_id, Choice.FOR);

        // Count votes abstaining
        let (abstain) = Voting_vote_power_store.read(proposal_id, Choice.ABSTAIN);

        // Count votes against
        let (against) = Voting_vote_power_store.read(proposal_id, Choice.AGAINST);

        let (partial_power, overflow1) = uint256_add(for, abstain);

        let (total_power, overflow2) = uint256_add(partial_power, against);

        let quorum = proposal.quorum;
        let (is_lower_or_equal) = uint256_le(quorum, total_power);

        // If overflow1 or overflow2 happened, then quorum has necessarily been reached because `quorum` is by definition smaller or equal to Uint256::MAX.
        // If `is_lower_or_equal` (meaning `_quorum` is smaller than `total_power`), then quorum has been reached (definition of quorum).
        // So if `overflow1 || overflow2 || is_lower_or_equal`, we have reached quorum. If we sum them and find `0`, then they're all equal to 0, which means
        // quorum has not been reached.
        if (overflow1 + overflow2 + is_lower_or_equal == 0) {
            let voting_period_has_ended = is_le(max_end_timestamp, current_timestamp + 1);
            if (voting_period_has_ended == FALSE) {
                with_attr error_message("Voting: Quorum has not been reached") {
                    assert 1 = 0;
                    return ();
                }
            } else {
                // Voting period has ended but quorum hasn't been reached: proposal should be `REJECTED`
                tempvar proposal_outcome = ProposalOutcome.REJECTED;

                // Cairo trick to prevent revoked reference
                tempvar range_check_ptr = range_check_ptr;
            }
        } else {
            // Quorum has been reached: set proposal outcome accordingly
            // Note: The proposal is rejected if for and against votes are equal.
            let (has_passed) = uint256_lt(against, for);

            if (has_passed == 1) {
                tempvar proposal_outcome = ProposalOutcome.ACCEPTED;
            } else {
                tempvar proposal_outcome = ProposalOutcome.REJECTED;
            }

            // Cairo trick to prevent revoked reference
            tempvar range_check_ptr = range_check_ptr;
        }

        let (is_valid) = Voting_execution_strategies_store.read(proposal.execution_strategy);
        if (is_valid == 0) {
            // execution_strategy has been removed from the whitelist. Cancel this execution.
            tempvar proposal_outcome = ProposalOutcome.CANCELLED;
        } else {
            // Cairo trick to prevent revoked reference
            tempvar proposal_outcome = proposal_outcome;
        }

        // Emit event
        proposal_finalized.emit(proposal_id, proposal_outcome);

        // Execute proposal Transactions
        // There are 2 situations:
        // 1) Starknet execution strategy - then txs are executed directly by this contract.
        // 2) Other execution strategy - then tx are executed by the specified execution strategy contract.

        if (proposal.execution_strategy == 1) {
            // Starknet execution strategy so we execute the proposal txs directly
            if (proposal_outcome == ProposalOutcome.ACCEPTED) {
                let (call_array_len, call_array, calldata_len, calldata) = _decode_execution_params(
                    execution_params_len, execution_params
                );
                let (response_len, response) = _execute_proposal_txs(
                    call_array_len, call_array, calldata_len, calldata
                );
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
                tempvar ecdsa_ptr = ecdsa_ptr;
                tempvar bitwise_ptr = bitwise_ptr;
            } else {
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
                tempvar ecdsa_ptr = ecdsa_ptr;
                tempvar bitwise_ptr = bitwise_ptr;
            }
        } else {
            // Other execution strategy, so we forward the txs to the specified execution strategy contract.
            IExecutionStrategy.execute(
                contract_address=proposal.execution_strategy,
                proposal_outcome=proposal_outcome,
                execution_params_len=execution_params_len,
                execution_params=execution_params,
            );
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            tempvar ecdsa_ptr = ecdsa_ptr;
            tempvar bitwise_ptr = bitwise_ptr;
        }

        // Flag this proposal as executed
        Voting_executed_proposals_store.write(proposal_id, 1);

        return ();
    }

    // @dev Cancels a proposal
    // @param proposal_id The ID of the proposal
    // @param execution_params Execution parameters for the proposal (must be the same as those submitted during proposal creation)
    func cancel_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposal_id: felt, execution_params_len: felt, execution_params: felt*
    ) {
        alloc_locals;

        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);

        // Make sure proposal has not already been executed
        with_attr error_message("Voting: Proposal already executed") {
            assert has_been_executed = 0;
        }

        let (proposal) = Voting_proposal_registry_store.read(proposal_id);
        with_attr error_message("Voting: Invalid proposal id") {
            // Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
            // be set to 0, hence the timestamps value will be set to 0 too.
            assert_not_zero(proposal.timestamps);
        }

        // Make sure execution params match the ones sent at proposal creation by checking that the hashes match
        let (recovered_hash) = ArrayUtils.hash(execution_params_len, execution_params);
        with_attr error_message("Voting: Invalid execution parameters") {
            assert recovered_hash = proposal.execution_hash;
        }

        let proposal_outcome = ProposalOutcome.CANCELLED;

        // Emit the event
        proposal_finalized.emit(proposal_id, proposal_outcome);

        if (proposal.execution_strategy != 1) {
            // Custom execution strategies may have different processes to follow when a proposal is cancelled.
            // Therefore, we still forward the execution payload to the specified strategy contract.
            IExecutionStrategy.execute(
                contract_address=proposal.execution_strategy,
                proposal_outcome=proposal_outcome,
                execution_params_len=execution_params_len,
                execution_params=execution_params,
            );
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            // In the case of starknet execution we do nothing if the proposal is cancelled.
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }

        // Flag this proposal as executed
        Voting_executed_proposals_store.write(proposal_id, 1);

        return ();
    }

    // @dev Checks to see whether a given address has voted in a proposal
    // @param proposal_id The proposal ID
    // @param voter_address The voter's address
    // @return voted 1 if user has voted, otherwise 0
    func has_voted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposal_id: felt, voter_address: Address
    ) -> (voted: felt) {
        return Voting_vote_registry_store.read(proposal_id, voter_address);
    }

    // @dev Returns proposal information
    // @param proposal_id The proposal ID
    // @return proposal_info Struct containing proposal information
    func get_proposal_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposal_id: felt
    ) -> (proposal_info: ProposalInfo) {
        let (proposal) = Voting_proposal_registry_store.read(proposal_id);
        with_attr error_message("Voting: Proposal does not exist") {
            assert_not_zero(proposal.timestamps);
        }

        let (power_against) = Voting_vote_power_store.read(proposal_id, Choice.AGAINST);
        let (power_for) = Voting_vote_power_store.read(proposal_id, Choice.FOR);
        let (power_abstain) = Voting_vote_power_store.read(proposal_id, Choice.ABSTAIN);
        return (
            ProposalInfo(proposal=proposal, power_for=power_for, power_against=power_against, power_abstain=power_abstain),
        );
    }
}

//
// Internal Functions
//

func _unchecked_add_execution_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(addresses_len: felt, addresses: felt*) {
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_execution_strategies_store.write(addresses[0], 1);
        _unchecked_add_execution_strategies(addresses_len - 1, &addresses[1]);
        return ();
    }
}

func _unchecked_remove_execution_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(addresses_len: felt, addresses: felt*) {
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_execution_strategies_store.write(addresses[0], 0);
        _unchecked_remove_execution_strategies(addresses_len - 1, &addresses[1]);
        return ();
    }
}

func _unchecked_add_voting_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(addresses_len: felt, addresses: felt*, params_all: Immutable2DArray) {
    alloc_locals;
    let (prev_index) = Voting_num_voting_strategies_store.read();
    _unchecked_add_voting_strategies_recurse(addresses_len, addresses, params_all, prev_index, 0);
    // Incrementing the voting strategies counter by the number of strategies added
    Voting_num_voting_strategies_store.write(prev_index + addresses_len);
    return ();
}

func _unchecked_add_voting_strategies_recurse{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    addresses_len: felt,
    addresses: felt*,
    params_all: Immutable2DArray,
    next_index: felt,
    index: felt,
) {
    alloc_locals;
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_voting_strategies_store.write(next_index, addresses[0]);
        // Extract voting params for the voting strategy
        let (params_len, params) = ArrayUtils.get_sub_array(params_all, index);
        // We store the length of the voting strategy params array at index zero
        Voting_voting_strategy_params_store.write(next_index, 0, params_len);
        // The following elements are the actual params
        _unchecked_add_voting_strategy_params(next_index, 1, params_len, params);
        _unchecked_add_voting_strategies_recurse(
            addresses_len - 1, &addresses[1], params_all, next_index + 1, index + 1
        );
        return ();
    }
}

func _unchecked_add_voting_strategy_params{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(strategy_index: felt, param_index: felt, params_len: felt, params: felt*) {
    if (params_len == 0) {
        // List is empty
        return ();
    } else {
        // Store voting parameter
        Voting_voting_strategy_params_store.write(strategy_index, param_index, params[0]);
        _unchecked_add_voting_strategy_params(
            strategy_index, param_index + 1, params_len - 1, &params[1]
        );
        return ();
    }
}

func _unchecked_remove_voting_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(indexes_len: felt, indexes: felt*) {
    if (indexes_len == 0) {
        return ();
    } else {
        Voting_voting_strategies_store.write(indexes[0], 0);
        // The length of the voting strategy params is stored at index zero
        let (params_len) = Voting_voting_strategy_params_store.read(indexes[0], 0);
        Voting_voting_strategy_params_store.write(indexes[0], 0, 0);
        // Removing voting strategy params
        _unchecked_remove_voting_strategy_params(indexes[0], params_len, 1);
        _unchecked_remove_voting_strategies(indexes_len - 1, &indexes[1]);
        return ();
    }
}

func _unchecked_remove_voting_strategy_params{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(strategy_index: felt, param_index: felt, params_len: felt) {
    if (params_len == 0) {
        // List is empty
        return ();
    }
    if (param_index == params_len + 1) {
        // All params have been removed from the array
        return ();
    }
    // Remove voting parameter
    Voting_voting_strategy_params_store.write(strategy_index, param_index, 0);
    _unchecked_remove_voting_strategy_params(strategy_index, param_index + 1, params_len);
    return ();
}

func _unchecked_add_authenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    addresses_len: felt, addresses: felt*
) {
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_authenticators_store.write(addresses[0], 1);
        _unchecked_add_authenticators(addresses_len - 1, &addresses[1]);
        return ();
    }
}

func _unchecked_remove_authenticators{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(addresses_len: felt, addresses: felt*) {
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_authenticators_store.write(addresses[0], 0);
        _unchecked_remove_authenticators(addresses_len - 1, &addresses[1]);
    }
    return ();
}

// Throws if the caller address is not a member of the set of whitelisted authenticators (stored in the `authenticators` mapping)
func _assert_valid_authenticator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    let (caller_address) = get_caller_address();
    let (is_valid) = Voting_authenticators_store.read(caller_address);
    with_attr error_message("Voting: Invalid authenticator") {
        assert_not_zero(is_valid);
    }

    return ();
}

// Throws if `execution_strategy` is not a member of the set of whitelisted execution_strategies
func _assert_valid_execution_strategy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(execution_strategy: felt) {
    let (is_valid) = Voting_execution_strategies_store.read(execution_strategy);
    with_attr error_message("Voting: Invalid execution strategy") {
        assert is_valid = 1;
    }

    return ();
}

func _assert_no_active_proposal_recurse{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(proposal_id: felt) {
    if (proposal_id == 0) {
        return ();
    } else {
        // Ensure each proposal has been executed
        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);
        assert has_been_executed = 1;
        _assert_no_active_proposal_recurse(proposal_id - 1);
        return ();
    }
}

func _assert_no_active_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (next_proposal) = Voting_next_proposal_nonce_store.read();
    // Using `next_proposal - 1` because `next_proposal` corresponds to the *next* nonce
    // so we need to substract one. This is safe because latest_proposal is at least 1 because
    // the constructor initializes the nonce to 1.
    let latest_proposal = next_proposal - 1;
    with_attr error_message("Voting: Some proposals are still active") {
        _assert_no_active_proposal_recurse(latest_proposal);
    }
    return ();
}

// Computes the cumulated voting power of a user by iterating over the voting strategies of `used_voting_strategies`.
// TODO: In the future we will need to transition to an array of `voter_address` because they might be different for different voting strategies.
func _get_cumulative_voting_power{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    current_timestamp: felt,
    voter_address: Address,
    used_voting_strategies_len: felt,
    used_voting_strategies: felt*,
    user_voting_strategy_params_all: Immutable2DArray,
    index: felt,
) -> (voting_power: Uint256) {
    // Make sure there are no duplicates to avoid an attack where people double count a voting strategy
    ArrayUtils.assert_no_duplicates(used_voting_strategies_len, used_voting_strategies);

    return _unchecked_get_cumulative_voting_power(
        current_timestamp,
        voter_address,
        used_voting_strategies_len,
        used_voting_strategies,
        user_voting_strategy_params_all,
        index,
    );
}

// Actual computation of voting power. Unchecked because duplicates are not checked in `used_voting_strategies`. The caller is
// expected to check for duplicates before calling this function.
func _unchecked_get_cumulative_voting_power{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(
    current_timestamp: felt,
    voter_address: Address,
    used_voting_strategies_len: felt,
    used_voting_strategies: felt*,
    user_voting_strategy_params_all: Immutable2DArray,
    index: felt,
) -> (voting_power: Uint256) {
    alloc_locals;

    if (used_voting_strategies_len == 0) {
        // Reached the end, stop iteration
        return (Uint256(0, 0),);
    }

    let strategy_index = used_voting_strategies[0];

    let (strategy_address) = Voting_voting_strategies_store.read(strategy_index);

    with_attr error_message("Voting: Invalid voting strategy") {
        assert_not_zero(strategy_address);
    }

    // Extract voting params array for the voting strategy specified by the index
    let (user_voting_strategy_params_len, user_voting_strategy_params) = ArrayUtils.get_sub_array(
        user_voting_strategy_params_all, index
    );

    // Initialize empty array to store voting params
    let (voting_strategy_params: felt*) = alloc();

    // Check that voting strategy params exist by the length which is stored in the first element of the array
    let (voting_strategy_params_len) = Voting_voting_strategy_params_store.read(strategy_index, 0);

    let (voting_strategy_params_len, voting_strategy_params) = _get_voting_strategy_params(
        strategy_index, voting_strategy_params_len, voting_strategy_params, 1
    );

    let (user_voting_power) = IVotingStrategy.getVotingPower(
        contract_address=strategy_address,
        timestamp=current_timestamp,
        voter_address=voter_address,
        params_len=voting_strategy_params_len,
        params=voting_strategy_params,
        user_params_len=user_voting_strategy_params_len,
        user_params=user_voting_strategy_params,
    );

    let (additional_voting_power) = _get_cumulative_voting_power(
        current_timestamp,
        voter_address,
        used_voting_strategies_len - 1,
        &used_voting_strategies[1],
        user_voting_strategy_params_all,
        index + 1,
    );

    let (voting_power, overflow) = uint256_add(user_voting_power, additional_voting_power);
    with_attr error_message("Voting: Overflow while computing voting power") {
        assert overflow = 0;
    }

    return (voting_power,);
}

// Function to reconstruct voting param array for voting strategy specified
func _get_voting_strategy_params{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    strategy_index: felt, params_len: felt, params: felt*, index: felt
) -> (params_len: felt, params: felt*) {
    // If there are no parameters, we just return an empty array
    if (params_len == 0) {
        return (0, params);
    }
    let (param) = Voting_voting_strategy_params_store.read(strategy_index, index);
    assert params[index - 1] = param;
    // All parameters have been added to the array so we can return it
    if (index == params_len) {
        return (params_len, params);
    }
    let (params_len, params) = _get_voting_strategy_params(
        strategy_index, params_len, params, index + 1
    );
    return (params_len, params);
}

// Decodes an array into the data required to perform a set of calls according to the OZ account standard
func _decode_execution_params{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    execution_params_len: felt, execution_params: felt*
) -> (call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) {
    assert_le(4, execution_params_len);  // Min execution params length is 4 (corresponding to 1 tx with no calldata)
    let call_array_len = (execution_params[0] - 1) / 4;  // Number of calls in the proposal payload
    let call_array = cast(&execution_params[1], AccountCallArray*);
    let calldata_len = execution_params_len - execution_params[0];
    let calldata = &execution_params[execution_params[0]];
    return (call_array_len, call_array, calldata_len, calldata);
}

// Same as OZ `execute` just without the assert  get_caller_address() = 0
// This is a reentrant call guard which prevents another account calling execute
// In the context of proposal txs, reentrancy is not an issue as the transactions are trusted to be non malicious
func _execute_proposal_txs{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) -> (
    response_len: felt, response: felt*
) {
    alloc_locals;
    let (tx_info) = get_tx_info();
    with_attr error_message("Voting: invalid tx version") {
        assert tx_info.version = 1;
    }
    // TMP: Convert `AccountCallArray` to 'Call'.
    let (calls: Call*) = alloc();
    Account._from_call_array_to_call(call_array_len, call_array, calldata, calls);
    let calls_len = call_array_len;
    // execute call
    let (response: felt*) = alloc();
    let (response_len) = Account._execute_list(calls_len, calls, response);
    return (response_len=response_len, response=response);
}
