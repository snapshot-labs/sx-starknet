// SPDX-License-Identifier: MIT

%lang starknet

// Standard Library
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp, get_tx_info
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt, uint256_le, uint256_eq
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import (
    assert_lt,
    assert_le,
    assert_nn,
    assert_nn_le,
    assert_not_zero,
    assert_lt_felt,
    assert_not_equal,
)

// OpenZeppelin
from openzeppelin.access.ownable.library import Ownable
from openzeppelin.account.library import Account, AccountCallArray, Call

// Interfaces
from contracts.starknet.Interfaces.IVotingStrategy import IVotingStrategy
from contracts.starknet.Interfaces.IExecutionStrategy import IExecutionStrategy

// Types
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.proposal import Proposal
from contracts.starknet.lib.proposal_info import ProposalInfo
from contracts.starknet.lib.vote import Vote
from contracts.starknet.lib.choice import Choice
from contracts.starknet.lib.proposal_outcome import ProposalOutcome

// Libraries
from contracts.starknet.lib.array_utils import ArrayUtils, Immutable2DArray

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
func Voting_executors_store(executor_address: felt) -> (is_valid: felt) {
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
func Voting_vote_registry_store(proposal_id: felt, voter_address: Address) -> (vote: Vote) {
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
func vote_created(proposal_id: felt, voter_address: Address, vote: Vote) {
}

@event
func controller_updated(previous: felt, new_controller: felt) {
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
func authenticators_added(added_len: felt, added: felt*) {
}

@event
func authenticators_removed(removed_len: felt, removed: felt*) {
}

@event
func executors_added(added_len: felt, added: felt*) {
}

@event
func executors_removed(removed_len: felt, removed: felt*) {
}

@event
func voting_strategies_added(added_len: felt, added: felt*) {
}

@event
func voting_strategies_removed(removed_len: felt, removed: felt*) {
}

namespace Voting {
    //
    // initializer
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        voting_delay: felt,
        min_voting_duration: felt,
        max_voting_duration: felt,
        proposal_threshold: Uint256,
        controller: felt,
        quorum: Uint256,
        voting_strategy_params_flat_len: felt,
        voting_strategy_params_flat: felt*,
        voting_strategies_len: felt,
        voting_strategies: felt*,
        authenticators_len: felt,
        authenticators: felt*,
        executors_len: felt,
        executors: felt*,
    ) {
        alloc_locals;

        // Sanity checks
        with_attr error_message("Invalid constructor parameters") {
            assert_nn(voting_delay);
            assert_le(min_voting_duration, max_voting_duration);
            assert_not_zero(controller);
            assert_not_zero(voting_strategies_len);
            assert_not_zero(authenticators_len);
            assert_not_zero(executors_len);
        }
        // TODO: maybe use uint256_signed_nn to check proposal_threshold?

        // Initialize the storage variables
        Voting_voting_delay_store.write(voting_delay);
        Voting_min_voting_duration_store.write(min_voting_duration);
        Voting_max_voting_duration_store.write(max_voting_duration);
        Voting_proposal_threshold_store.write(proposal_threshold);
        Ownable.initializer(controller);
        Voting_quorum_store.write(quorum);

        // Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        // Currently there is no way to pass struct types with pointers in calldata, so we must do it this way.
        let (voting_strategy_params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            voting_strategy_params_flat_len, voting_strategy_params_flat
        );

        unchecked_add_voting_strategies(
            voting_strategies_len, voting_strategies, voting_strategy_params_all
        );
        unchecked_add_authenticators(authenticators_len, authenticators);
        unchecked_add_execution_strategies(executors_len, executors);

        // The first proposal in a space will have a proposal ID of 1.
        Voting_next_proposal_nonce_store.write(1);

        return ();
    }

    func update_controller{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        new_controller: felt
    ) {
        alloc_locals;
        Ownable.assert_only_owner();

        let (previous_controller) = Ownable.owner();

        Ownable.transfer_ownership(new_controller);

        controller_updated.emit(previous_controller, new_controller);
        return ();
    }

    func update_quorum{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        new_quorum: Uint256
    ) {
        Ownable.assert_only_owner();

        let (previous_quorum) = Voting_quorum_store.read();

        Voting_quorum_store.write(new_quorum);

        quorum_updated.emit(previous_quorum, new_quorum);
        return ();
    }

    func update_voting_delay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        new_voting_delay: felt
    ) {
        Ownable.assert_only_owner();

        let (previous_delay) = Voting_voting_delay_store.read();

        Voting_voting_delay_store.write(new_voting_delay);

        voting_delay_updated.emit(previous_delay, new_voting_delay);

        return ();
    }

    func update_min_voting_duration{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(new_min_voting_duration: felt) {
        Ownable.assert_only_owner();

        let (previous_min_voting_duration) = Voting_min_voting_duration_store.read();

        let (max_voting_duration) = Voting_max_voting_duration_store.read();

        with_attr error_message("Min voting duration must be less than max voting duration") {
            assert_le(new_min_voting_duration, max_voting_duration);
        }

        Voting_min_voting_duration_store.write(new_min_voting_duration);

        min_voting_duration_updated.emit(previous_min_voting_duration, new_min_voting_duration);

        return ();
    }

    func update_max_voting_duration{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(new_max_voting_duration: felt) {
        Ownable.assert_only_owner();

        let (previous_max_voting_duration) = Voting_max_voting_duration_store.read();

        let (min_voting_duration) = Voting_min_voting_duration_store.read();

        with_attr error_message("Max voting duration must be greater than min voting duration") {
            assert_le(min_voting_duration, new_max_voting_duration);
        }

        Voting_max_voting_duration_store.write(new_max_voting_duration);

        max_voting_duration_updated.emit(previous_max_voting_duration, new_max_voting_duration);

        return ();
    }

    func update_proposal_threshold{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(new_proposal_threshold: Uint256) {
        Ownable.assert_only_owner();

        let (previous_proposal_threshold) = Voting_proposal_threshold_store.read();

        Voting_proposal_threshold_store.write(new_proposal_threshold);

        proposal_threshold_updated.emit(previous_proposal_threshold, new_proposal_threshold);

        return ();
    }

    func add_execution_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*) {
        alloc_locals;

        Ownable.assert_only_owner();

        unchecked_add_execution_strategies(addresses_len, addresses);

        executors_added.emit(addresses_len, addresses);
        return ();
    }

    func remove_execution_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*) {
        alloc_locals;

        Ownable.assert_only_owner();

        unchecked_remove_execution_strategies(addresses_len, addresses);

        executors_removed.emit(addresses_len, addresses);
        return ();
    }

    func add_voting_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*, params_flat_len: felt, params_flat: felt*) {
        alloc_locals;

        Ownable.assert_only_owner();

        assert_no_active_proposal();

        let (params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            params_flat_len, params_flat
        );

        unchecked_add_voting_strategies(addresses_len, addresses, params_all);

        voting_strategies_added.emit(addresses_len, addresses);
        return ();
    }

    func remove_voting_strategies{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(indexes_len: felt, indexes: felt*) {
        alloc_locals;

        Ownable.assert_only_owner();

        assert_no_active_proposal();

        unchecked_remove_voting_strategies(indexes_len, indexes);
        voting_strategies_removed.emit(indexes_len, indexes);
        return ();
    }

    func add_authenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        addresses_len: felt, addresses: felt*
    ) {
        alloc_locals;

        Ownable.assert_only_owner();

        assert_no_active_proposal();

        unchecked_add_authenticators(addresses_len, addresses);

        authenticators_added.emit(addresses_len, addresses);
        return ();
    }

    func remove_authenticators{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
    }(addresses_len: felt, addresses: felt*) {
        alloc_locals;

        Ownable.assert_only_owner();

        assert_no_active_proposal();

        unchecked_remove_authenticators(addresses_len, addresses);

        authenticators_removed.emit(addresses_len, addresses);
        return ();
    }

    //
    // Business logic
    //

    func vote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
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
        assert_valid_authenticator();

        // Make sure proposal has not already been executed
        with_attr error_message("Proposal already executed") {
            let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);
            assert has_been_executed = 0;
        }

        let (proposal) = Voting_proposal_registry_store.read(proposal_id);
        with_attr error_message("Proposal does not exist") {
            // Asserting start timestamp is not zero because start timestamp
            // is necessarily > 0 when creating a new proposal.
            assert_not_zero(proposal.start_timestamp);
        }

        // The snapshot timestamp at which voting power will be taken
        let snapshot_timestamp = proposal.snapshot_timestamp;

        let (current_timestamp) = get_block_timestamp();
        // Make sure proposal is still open for voting
        with_attr error_message("Voting period has ended") {
            assert_lt(current_timestamp, proposal.max_end_timestamp);
        }

        // Make sure proposal has started
        with_attr error_message("Voting has not started yet") {
            assert_le(proposal.start_timestamp, current_timestamp);
        }

        // Make sure voter has not already voted
        let (prev_vote) = Voting_vote_registry_store.read(proposal_id, voter_address);

        with_attr error_message("User already voted") {
            assert prev_vote.choice = 0;
        }

        // Make sure `choice` is a valid choice
        with_attr error_message("Invalid choice") {
            assert_le(Choice.FOR, choice);
            assert_le(choice, Choice.ABSTAIN);
        }

        // Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        let (user_voting_strategy_params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        );

        let (user_voting_power) = get_cumulative_voting_power(
            snapshot_timestamp,
            voter_address,
            used_voting_strategies_len,
            used_voting_strategies,
            user_voting_strategy_params_all,
            0,
        );

        let (no_voting_power) = uint256_eq(Uint256(0, 0), user_voting_power);

        with_attr error_message("No voting power for user") {
            assert no_voting_power = 0;
        }

        let (previous_voting_power) = Voting_vote_power_store.read(proposal_id, choice);
        let (new_voting_power, overflow) = uint256_add(user_voting_power, previous_voting_power);

        with_attr error_message("Overflow in voting power") {
            assert overflow = 0;
        }

        Voting_vote_power_store.write(proposal_id, choice, new_voting_power);

        let vote = Vote(choice=choice, voting_power=user_voting_power);
        Voting_vote_registry_store.write(proposal_id, voter_address, vote);

        // Emit event
        vote_created.emit(proposal_id, voter_address, vote);

        return ();
    }

    func propose{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposer_address: Address,
        metadata_uri_string_len: felt,
        metadata_uri_len: felt,
        metadata_uri: felt*,
        executor: felt,
        used_voting_strategies_len: felt,
        used_voting_strategies: felt*,
        user_voting_strategy_params_flat_len: felt,
        user_voting_strategy_params_flat: felt*,
        execution_params_len: felt,
        execution_params: felt*,
    ) -> () {
        alloc_locals;

        // Verify that the caller is the authenticator contract.
        assert_valid_authenticator();

        // Verify that the executor address is one of the whitelisted addresses
        assert_valid_executor(executor);

        // The snapshot for the proposal is the current timestamp at proposal creation
        // We use a timestamp instead of a block number to define a snapshot so that the system can generalize to multi-chain
        // TODO: Need to consider what sort of guarantees we have on the timestamp returned being correct.
        let (snapshot_timestamp) = get_block_timestamp();
        let (delay) = Voting_voting_delay_store.read();

        let (_min_voting_duration) = Voting_min_voting_duration_store.read();
        let (_max_voting_duration) = Voting_max_voting_duration_store.read();

        // Define start_timestamp, min_end and max_end
        let start_timestamp = snapshot_timestamp + delay;
        let min_end_timestamp = start_timestamp + _min_voting_duration;
        let max_end_timestamp = start_timestamp + _max_voting_duration;

        // Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        let (user_voting_strategy_params_all: Immutable2DArray) = ArrayUtils.construct_array2d(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        );

        let (voting_power) = get_cumulative_voting_power(
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
        with_attr error_message("Not enough voting power") {
            assert has_enough_vp = 1;
        }

        // Hash the execution params
        // Storing arrays inside a struct is impossible so instead we just store a hash and then reconstruct the array in finalize_proposal
        let (execution_hash) = ArrayUtils.hash(execution_params_len, execution_params);

        let (_quorum) = Voting_quorum_store.read();

        // Create the proposal and its proposal id
        let proposal = Proposal(
            _quorum,
            snapshot_timestamp,
            start_timestamp,
            min_end_timestamp,
            max_end_timestamp,
            executor,
            execution_hash,
        );

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

    // Finalizes the proposal, counts the voting power, and send the corresponding result to the L1 executor contract
    @external
    func finalize_proposal{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
    }(proposal_id: felt, execution_params_len: felt, execution_params: felt*) {
        alloc_locals;

        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);

        // Make sure proposal has not already been executed
        with_attr error_message("Proposal already executed") {
            assert has_been_executed = 0;
        }

        let (proposal) = Voting_proposal_registry_store.read(proposal_id);
        with_attr error_message("Invalid proposal id") {
            // Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
            // be set to 0, hence the snapshot timestamp will be set to 0 too.
            assert_not_zero(proposal.snapshot_timestamp);
        }

        // Make sure proposal period has ended
        let (current_timestamp) = get_block_timestamp();
        with_attr error_message("Min voting period has not elapsed") {
            assert_le(proposal.min_end_timestamp, current_timestamp);
        }

        // Make sure execution params match the ones sent at proposal creation by checking that the hashes match
        let (recovered_hash) = ArrayUtils.hash(execution_params_len, execution_params);
        with_attr error_message("Invalid execution parameters") {
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

        let _quorum = proposal.quorum;
        let (is_lower_or_equal) = uint256_le(_quorum, total_power);

        // If overflow1 or overflow2 happened, then quorum has necessarily been reached because `quorum` is by definition smaller or equal to Uint256::MAX.
        // If `is_lower_or_equal` (meaning `_quorum` is smaller than `total_power`), then quorum has been reached (definition of quorum).
        // So if `overflow1 || overflow2 || is_lower_or_equal`, we have reached quorum. If we sum them and find `0`, then they're all equal to 0, which means
        // quorum has not been reached.
        if (overflow1 + overflow2 + is_lower_or_equal == 0) {
            let voting_period_has_ended = is_le(proposal.max_end_timestamp, current_timestamp + 1);
            if (voting_period_has_ended == FALSE) {
                with_attr error_message("Quorum has not been reached") {
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
            let (has_passed) = uint256_lt(against, for);

            if (has_passed == 1) {
                tempvar proposal_outcome = ProposalOutcome.ACCEPTED;
            } else {
                tempvar proposal_outcome = ProposalOutcome.REJECTED;
            }

            // Cairo trick to prevent revoked reference
            tempvar range_check_ptr = range_check_ptr;
        }

        let (is_valid) = Voting_executors_store.read(proposal.executor);
        if (is_valid == 0) {
            // Executor has been removed from the whitelist. Cancel this execution.
            tempvar proposal_outcome = ProposalOutcome.CANCELLED;
        } else {
            // Cairo trick to prevent revoked reference
            tempvar proposal_outcome = proposal_outcome;
        }

        // Execute proposal Transactions
        // There are 2 situations:
        // 1) Starknet execution strategy - then txs are executed directly by this contract.
        // 2) Other execution strategy - then tx are executed by the specified execution strategy contract.

        if (proposal.executor == 1) {
            // Starknet execution strategy so we execute the proposal txs directly
            if (proposal_outcome == ProposalOutcome.ACCEPTED) {
                let (call_array_len, call_array, calldata_len, calldata) = decode_execution_params(
                    execution_params_len, execution_params
                );
                let (response_len, response) = execute_proposal_txs(
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
                contract_address=proposal.executor,
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

    // Cancels the proposal. Only callable by the controller.
    func cancel_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposal_id: felt, execution_params_len: felt, execution_params: felt*
    ) {
        alloc_locals;

        Ownable.assert_only_owner();

        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);

        // Make sure proposal has not already been executed
        with_attr error_message("Proposal already executed") {
            assert has_been_executed = 0;
        }

        let (proposal) = Voting_proposal_registry_store.read(proposal_id);
        with_attr error_message("Invalid proposal id") {
            // Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
            // be set to 0, hence the snapshot timestamp will be set to 0 too.
            assert_not_zero(proposal.snapshot_timestamp);
        }

        let proposal_outcome = ProposalOutcome.CANCELLED;

        if (proposal.executor != 1) {
            // Custom execution strategies may have different processes to follow when a proposal is cancelled.
            // Therefore, we still forward the execution payload to the specified strategy contract.
            IExecutionStrategy.execute(
                contract_address=proposal.executor,
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

    //
    // View functions
    //

    @view
    func get_vote_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        voter_address: Address, proposal_id: felt
    ) -> (vote: Vote) {
        return Voting_vote_registry_store.read(proposal_id, voter_address);
    }

    @view
    func get_proposal_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        proposal_id: felt
    ) -> (proposal_info: ProposalInfo) {
        let (proposal) = Voting_proposal_registry_store.read(proposal_id);

        let (_power_against) = Voting_vote_power_store.read(proposal_id, Choice.AGAINST);
        let (_power_for) = Voting_vote_power_store.read(proposal_id, Choice.FOR);
        let (_power_abstain) = Voting_vote_power_store.read(proposal_id, Choice.ABSTAIN);
        return (
            ProposalInfo(proposal=proposal, power_for=_power_for, power_against=_power_against, power_abstain=_power_abstain),
        );
    }
}

//
//  Internal Functions
//

func unchecked_add_execution_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(addresses_len: felt, addresses: felt*) {
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_executors_store.write(addresses[0], 1);

        unchecked_add_execution_strategies(addresses_len - 1, &addresses[1]);
        return ();
    }
}

func unchecked_remove_execution_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(addresses_len: felt, addresses: felt*) {
    if (addresses_len == 0) {
        return ();
    } else {
        Voting_executors_store.write(addresses[0], 0);

        unchecked_remove_execution_strategies(addresses_len - 1, &addresses[1]);
        return ();
    }
}

func unchecked_add_voting_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(addresses_len: felt, addresses: felt*, params_all: Immutable2DArray) {
    alloc_locals;
    let (prev_index) = Voting_num_voting_strategies_store.read();
    unchecked_add_voting_strategies_recurse(addresses_len, addresses, params_all, prev_index, 0);
    // Incrementing the voting strategies counter by the number of strategies added
    Voting_num_voting_strategies_store.write(prev_index + addresses_len);
    return ();
}

func unchecked_add_voting_strategies_recurse{
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
        unchecked_add_voting_strategy_params(next_index, 1, params_len, params);

        unchecked_add_voting_strategies_recurse(
            addresses_len - 1, &addresses[1], params_all, next_index + 1, index + 1
        );
        return ();
    }
}

func unchecked_add_voting_strategy_params{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(strategy_index: felt, param_index: felt, params_len: felt, params: felt*) {
    if (params_len == 0) {
        // List is empty
        return ();
    } else {
        // Store voting parameter
        Voting_voting_strategy_params_store.write(strategy_index, param_index, params[0]);

        unchecked_add_voting_strategy_params(
            strategy_index, param_index + 1, params_len - 1, &params[1]
        );
        return ();
    }
}

func unchecked_remove_voting_strategies{
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
        unchecked_remove_voting_strategy_params(indexes[0], params_len, 1);

        unchecked_remove_voting_strategies(indexes_len - 1, &indexes[1]);
        return ();
    }
}

func unchecked_remove_voting_strategy_params{
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

    unchecked_remove_voting_strategy_params(strategy_index, param_index + 1, params_len);
    return ();
}

func unchecked_add_authenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to_add_len: felt, to_add: felt*
) {
    if (to_add_len == 0) {
        return ();
    } else {
        Voting_authenticators_store.write(to_add[0], 1);

        unchecked_add_authenticators(to_add_len - 1, &to_add[1]);
        return ();
    }
}

func unchecked_remove_authenticators{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(to_remove_len: felt, to_remove: felt*) {
    if (to_remove_len == 0) {
        return ();
    } else {
        Voting_authenticators_store.write(to_remove[0], 0);

        unchecked_remove_authenticators(to_remove_len - 1, &to_remove[1]);
    }
    return ();
}

// Throws if the caller address is not a member of the set of whitelisted authenticators (stored in the `authenticators` mapping)
func assert_valid_authenticator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller_address) = get_caller_address();
    let (is_valid) = Voting_authenticators_store.read(caller_address);

    // Ensure it has been initialized
    with_attr error_message("Invalid authenticator") {
        assert_not_zero(is_valid);
    }

    return ();
}

// Throws if `executor` is not a member of the set of whitelisted executors (stored in the `executors` mapping)
func assert_valid_executor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    executor: felt
) {
    let (is_valid) = Voting_executors_store.read(executor);

    with_attr error_message("Invalid executor") {
        assert is_valid = 1;
    }

    return ();
}

func assert_no_active_proposal_recurse{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(proposal_id: felt) {
    if (proposal_id == 0) {
        return ();
    } else {
        // Ensure the proposal has been executed
        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id);
        assert has_been_executed = 1;

        // Recurse
        assert_no_active_proposal_recurse(proposal_id - 1);
        return ();
    }
}

func assert_no_active_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (next_proposal) = Voting_next_proposal_nonce_store.read();

    // Using `next_proposal - 1` because `next_proposal` corresponds to the *next* nonce
    // so we need to substract one. This is safe because latest_proposal is at least 1 because
    // the constructor initializes the nonce to 1.
    let latest_proposal = next_proposal - 1;

    with_attr error_message("Some proposals are still active") {
        assert_no_active_proposal_recurse(latest_proposal);
    }
    return ();
}

// Asserts that the array does not contain any duplicates.
// O(N^2) as it loops over each element N times.
func assert_no_duplicates{}(array_len: felt, array: felt*) {
    if (array_len == 0) {
        return ();
    } else {
        let to_find = array[0];

        // For each element in the array, try to find
        // this element in the rest of the array
        let (found) = ArrayUtils.find(to_find, array_len - 1, &array[1]);

        // If the element was found, we have found a duplicate.
        // Raise an error!
        with_attr error_message("Duplicate entry found") {
            assert found = FALSE;
        }

        assert_no_duplicates(array_len - 1, &array[1]);
        return ();
    }
}

// Computes the cumulated voting power of a user by iterating over the voting strategies of `used_voting_strategies`.
// TODO: In the future we will need to transition to an array of `voter_address` because they might be different for different voting strategies.
func get_cumulative_voting_power{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    current_timestamp: felt,
    voter_address: Address,
    used_voting_strategies_len: felt,
    used_voting_strategies: felt*,
    user_voting_strategy_params_all: Immutable2DArray,
    index: felt,
) -> (voting_power: Uint256) {
    // Make sure there are no duplicates to avoid an attack where people double count a voting strategy
    assert_no_duplicates(used_voting_strategies_len, used_voting_strategies);

    return unchecked_get_cumulative_voting_power(
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
func unchecked_get_cumulative_voting_power{
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

    with_attr error_message("Invalid voting strategy") {
        assert_not_equal(strategy_address, 0);
    }

    // Extract voting params array for the voting strategy specified by the index
    let (user_voting_strategy_params_len, user_voting_strategy_params) = ArrayUtils.get_sub_array(
        user_voting_strategy_params_all, index
    );

    // Initialize empty array to store voting params
    let (voting_strategy_params: felt*) = alloc();

    // Check that voting strategy params exist by the length which is stored in the first element of the array
    let (voting_strategy_params_len) = Voting_voting_strategy_params_store.read(strategy_index, 0);

    let (voting_strategy_params_len, voting_strategy_params) = get_voting_strategy_params(
        strategy_index, voting_strategy_params_len, voting_strategy_params, 1
    );

    let (user_voting_power) = IVotingStrategy.get_voting_power(
        contract_address=strategy_address,
        timestamp=current_timestamp,
        voter_address=voter_address,
        params_len=voting_strategy_params_len,
        params=voting_strategy_params,
        user_params_len=user_voting_strategy_params_len,
        user_params=user_voting_strategy_params,
    );

    let (additional_voting_power) = get_cumulative_voting_power(
        current_timestamp,
        voter_address,
        used_voting_strategies_len - 1,
        &used_voting_strategies[1],
        user_voting_strategy_params_all,
        index + 1,
    );

    let (voting_power, overflow) = uint256_add(user_voting_power, additional_voting_power);

    with_attr error_message("Overflow while computing voting power") {
        assert overflow = 0;
    }

    return (voting_power,);
}

// Function to reconstruct voting param array for voting strategy specified
func get_voting_strategy_params{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    strategy_index: felt, params_len: felt, params: felt*, index: felt
) -> (params_len: felt, params: felt*) {
    // The are no parameters so we just return an empty array
    if (params_len == 0) {
        return (0, params);
    }

    let (param) = Voting_voting_strategy_params_store.read(strategy_index, index);
    assert params[index - 1] = param;

    // All parameters have been added to the array so we can return it
    if (index == params_len) {
        return (params_len, params);
    }

    let (params_len, params) = get_voting_strategy_params(
        strategy_index, params_len, params, index + 1
    );
    return (params_len, params);
}

// Decodes an array into the data required to perform a set of calls according to the OZ account standard
func decode_execution_params{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    execution_params_len: felt, execution_params: felt*
) -> (call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) {
    assert_nn_le(4, execution_params_len);  // Min execution params length is 4 (corresponding to 1 tx with no calldata)
    let call_array_len = (execution_params[0] - 1) / 4;  // Number of calls in the proposal payload
    let call_array = cast(&execution_params[1], AccountCallArray*);
    let calldata_len = execution_params_len - execution_params[0];
    let calldata = &execution_params[execution_params[0]];
    return (call_array_len, call_array, calldata_len, calldata);
}

// Same as OZ `execute` just without the assert  get_caller_address() = 0
// This is a reentrant call guard which prevents another account calling execute
// In the context of proposal txs, reentrancy is not an issue
func execute_proposal_txs{
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
    with_attr error_message("Account: invalid tx version") {
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
