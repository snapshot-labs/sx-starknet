# SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt, uint256_le
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.math import (
    assert_lt,
    assert_le,
    assert_nn,
    assert_nn_le,
    assert_not_zero,
    assert_lt_felt,
)

from openzeppelin.access.ownable import Ownable
from openzeppelin.account.library import Account, AccountCallArray, Account_current_nonce

from contracts.starknet.Interfaces.IVotingStrategy import IVotingStrategy
from contracts.starknet.Interfaces.IExecutionStrategy import IExecutionStrategy
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.proposal import Proposal
from contracts.starknet.lib.proposal_info import ProposalInfo
from contracts.starknet.lib.vote import Vote
from contracts.starknet.lib.choice import Choice
from contracts.starknet.lib.proposal_outcome import ProposalOutcome
from contracts.starknet.lib.hash_array import hash_array
from contracts.starknet.lib.array2d import Immutable2DArray, construct_array2d, get_sub_array
from contracts.starknet.lib.slot_key import get_slot_key

#
# Storage
#

@storage_var
func Voting_voting_delay_store() -> (delay : felt):
end

@storage_var
func Voting_min_voting_duration_store() -> (period : felt):
end

@storage_var
func Voting_max_voting_duration_store() -> (period : felt):
end

@storage_var
func Voting_proposal_threshold_store() -> (threshold : Uint256):
end

@storage_var
func Voting_quorum_store() -> (value : Uint256):
end

@storage_var
func Voting_authenticators_store(authenticator_address : felt) -> (is_valid : felt):
end

@storage_var
func Voting_executors_store(executor_address : felt) -> (is_valid : felt):
end

@storage_var
func Voting_voting_strategies_store(strategy_address : felt) -> (is_valid : felt):
end

@storage_var
func Voting_voting_strategy_params_store(voting_strategy_contract : felt, index : felt) -> (
    voting_strategy_param : felt
):
end

@storage_var
func Voting_next_proposal_nonce_store() -> (nonce : felt):
end

@storage_var
func Voting_proposal_registry_store(proposal_id : felt) -> (proposal : Proposal):
end

@storage_var
func Voting_executed_proposals_store(proposal_id : felt) -> (executed : felt):
end

@storage_var
func Voting_vote_registry_store(proposal_id : felt, voter_address : Address) -> (vote : Vote):
end

@storage_var
func Voting_vote_power_store(proposal_id : felt, choice : felt) -> (power : Uint256):
end

#
# Events
#

@event
func proposal_created(
    proposal_id : felt,
    proposer_address : Address,
    proposal : Proposal,
    metadata_uri_len : felt,
    metadata_uri : felt*,
    execution_params_len : felt,
    execution_params : felt*,
):
end

@event
func vote_created(proposal_id : felt, voter_address : Address, vote : Vote):
end

@event
func controller_updated(previous : felt, new_controller : felt):
end

@event
func quorum_updated(previous : Uint256, new_quorum : Uint256):
end

@event
func voting_delay_updated(previous : felt, new_voting_delay : felt):
end

@event
func min_voting_duration_updated(previous : felt, new_voting_duration : felt):
end

@event
func max_voting_duration_updated(previous : felt, new_voting_duration : felt):
end

@event
func proposal_threshold_updated(previous : Uint256, new_proposal_threshold : Uint256):
end

@event
func authenticators_added(added_len : felt, added : felt*):
end

@event
func authenticators_removed(removed_len : felt, removed : felt*):
end

@event
func executors_added(added_len : felt, added : felt*):
end

@event
func executors_removed(removed_len : felt, removed : felt*):
end

@event
func voting_strategies_added(added_len : felt, added : felt*):
end

@event
func voting_strategies_removed(removed_len : felt, removed : felt*):
end

namespace Voting:
    #
    # initializer
    #

    func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        _voting_delay : felt,
        _min_voting_duration : felt,
        _max_voting_duration : felt,
        _proposal_threshold : Uint256,
        _controller : felt,
        _quorum : Uint256,
        _voting_strategy_params_flat_len : felt,
        _voting_strategy_params_flat : felt*,
        _voting_strategies_len : felt,
        _voting_strategies : felt*,
        _authenticators_len : felt,
        _authenticators : felt*,
        _executors_len : felt,
        _executors : felt*,
    ):
        alloc_locals

        # Sanity checks
        with_attr error_message("Invalid constructor parameters"):
            assert_nn(_voting_delay)
            assert_le(_min_voting_duration, _max_voting_duration)
            assert_not_zero(_controller)
            assert_not_zero(_voting_strategies_len)
            assert_not_zero(_authenticators_len)
            assert_not_zero(_executors_len)
        end
        # TODO: maybe use uint256_signed_nn to check proposal_threshold?

        # Initialize the storage variables
        Voting_voting_delay_store.write(_voting_delay)
        Voting_min_voting_duration_store.write(_min_voting_duration)
        Voting_max_voting_duration_store.write(_max_voting_duration)
        Voting_proposal_threshold_store.write(_proposal_threshold)
        Ownable.initializer(_controller)
        Voting_quorum_store.write(_quorum)

        # Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        # Currently there is no way to pass struct types with pointers in calldata, so we must do it this way.
        let (voting_strategy_params_all : Immutable2DArray) = construct_array2d(
            _voting_strategy_params_flat_len, _voting_strategy_params_flat
        )

        unchecked_add_voting_strategies(
            _voting_strategies_len, _voting_strategies, voting_strategy_params_all, 0
        )
        unchecked_add_authenticators(_authenticators_len, _authenticators)
        unchecked_add_executors(_executors_len, _executors)

        # The first proposal in a space will have a proposal ID of 1.
        Voting_next_proposal_nonce_store.write(1)

        return ()
    end

    @external
    func update_controller{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(new_controller : felt):
        alloc_locals
        Ownable.assert_only_owner()

        let (previous_controller) = Ownable.owner()

        Ownable.transfer_ownership(new_controller)

        controller_updated.emit(previous_controller, new_controller)
        return ()
    end

    @external
    func update_quorum{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        new_quorum : Uint256
    ):
        Ownable.assert_only_owner()

        let (previous_quorum) = Voting_quorum_store.read()

        Voting_quorum_store.write(new_quorum)

        quorum_updated.emit(previous_quorum, new_quorum)
        return ()
    end

    @external
    func update_voting_delay{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(new_delay : felt):
        Ownable.assert_only_owner()

        let (previous_delay) = Voting_voting_delay_store.read()

        Voting_voting_delay_store.write(new_delay)

        voting_delay_updated.emit(previous_delay, new_delay)

        return ()
    end

    @external
    func update_min_voting_duration{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(new_min_duration : felt):
        Ownable.assert_only_owner()

        let (previous_duration) = Voting_min_voting_duration_store.read()

        let (max_duration) = Voting_max_voting_duration_store.read()

        assert_le(new_min_duration, max_duration)

        Voting_min_voting_duration_store.write(new_min_duration)

        min_voting_duration_updated.emit(previous_duration, new_min_duration)

        return ()
    end

    #
    # Setters
    #

    @external
    func update_max_voting_duration{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(new_max_duration : felt):
        Ownable.assert_only_owner()

        let (previous_duration) = Voting_max_voting_duration_store.read()

        let (min_duration) = Voting_min_voting_duration_store.read()

        assert_le(min_duration, new_max_duration)

        Voting_max_voting_duration_store.write(new_max_duration)

        max_voting_duration_updated.emit(previous_duration, new_max_duration)

        return ()
    end

    @external
    func update_proposal_threshold{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(new_threshold : Uint256):
        Ownable.assert_only_owner()

        let (previous_threshold) = Voting_proposal_threshold_store.read()

        Voting_proposal_threshold_store.write(new_threshold)

        proposal_threshold_updated.emit(previous_threshold, new_threshold)

        return ()
    end

    @external
    func add_executors{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        to_add_len : felt, to_add : felt*
    ):
        alloc_locals

        Ownable.assert_only_owner()

        unchecked_add_executors(to_add_len, to_add)

        executors_added.emit(to_add_len, to_add)
        return ()
    end

    @external
    func remove_executors{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        to_remove_len : felt, to_remove : felt*
    ):
        alloc_locals

        Ownable.assert_only_owner()

        unchecked_remove_executors(to_remove_len, to_remove)

        executors_removed.emit(to_remove_len, to_remove)
        return ()
    end

    @external
    func add_voting_strategies{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(to_add_len : felt, to_add : felt*, params_flat_len : felt, params_flat : felt*):
        alloc_locals

        Ownable.assert_only_owner()

        let (params_all : Immutable2DArray) = construct_array2d(params_flat_len, params_flat)

        unchecked_add_voting_strategies(to_add_len, to_add, params_all, 0)

        voting_strategies_added.emit(to_add_len, to_add)
        return ()
    end

    @external
    func remove_voting_strategies{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(to_remove_len : felt, to_remove : felt*):
        alloc_locals

        Ownable.assert_only_owner()

        unchecked_remove_voting_strategies(to_remove_len, to_remove)
        voting_strategies_removed.emit(to_remove_len, to_remove)
        return ()
    end

    @external
    func add_authenticators{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(to_add_len : felt, to_add : felt*):
        alloc_locals

        Ownable.assert_only_owner()

        unchecked_add_authenticators(to_add_len, to_add)

        authenticators_added.emit(to_add_len, to_add)
        return ()
    end

    @external
    func remove_authenticators{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(to_remove_len : felt, to_remove : felt*):
        alloc_locals

        Ownable.assert_only_owner()

        unchecked_remove_authenticators(to_remove_len, to_remove)

        authenticators_removed.emit(to_remove_len, to_remove)
        return ()
    end

    #
    # Business logic
    #

    @external
    func vote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        voter_address : Address,
        proposal_id : felt,
        choice : felt,
        used_voting_strategies_len : felt,
        used_voting_strategies : felt*,
        user_voting_strategy_params_flat_len : felt,
        user_voting_strategy_params_flat : felt*,
    ) -> ():
        alloc_locals

        # Verify that the caller is the authenticator contract.
        assert_valid_authenticator()

        # Make sure proposal has not already been executed
        with_attr error_message("Proposal already executed"):
            let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id)
            assert has_been_executed = 0
        end

        let (proposal) = Voting_proposal_registry_store.read(proposal_id)

        # The snapshot timestamp at which voting power will be taken
        let snapshot_timestamp = proposal.snapshot_timestamp

        let (current_timestamp) = get_block_timestamp()
        # Make sure proposal is still open for voting
        with_attr error_message("Voting period has ended"):
            assert_lt(current_timestamp, proposal.max_end_timestamp)
        end

        # Make sure proposal has started
        with_attr error_message("Voting has not started yet"):
            assert_le(proposal.start_timestamp, current_timestamp)
        end

        # Make sure voter has not already voted
        let (prev_vote) = Voting_vote_registry_store.read(proposal_id, voter_address)
        if prev_vote.choice != 0:
            # Voter has already voted!
            with_attr error_message("User already voted"):
                assert 1 = 0
            end
        end

        # Make sure `choice` is a valid choice
        with_attr error_message("Invalid choice"):
            assert_le(Choice.FOR, choice)
            assert_le(choice, Choice.ABSTAIN)
        end

        # Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        let (user_voting_strategy_params_all : Immutable2DArray) = construct_array2d(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        )

        let (user_voting_power) = get_cumulative_voting_power(
            snapshot_timestamp,
            voter_address,
            used_voting_strategies_len,
            used_voting_strategies,
            user_voting_strategy_params_all,
            0,
        )

        let (previous_voting_power) = Voting_vote_power_store.read(proposal_id, choice)
        let (new_voting_power, overflow) = uint256_add(user_voting_power, previous_voting_power)

        if overflow != 0:
            # Overflow happened, throw error
            with_attr error_message("Overflow"):
                assert 1 = 0
            end
        end

        Voting_vote_power_store.write(proposal_id, choice, new_voting_power)

        let vote = Vote(choice=choice, voting_power=user_voting_power)
        Voting_vote_registry_store.write(proposal_id, voter_address, vote)

        # Emit event
        vote_created.emit(proposal_id, voter_address, vote)

        return ()
    end

    @external
    func propose{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        proposer_address : Address,
        metadata_uri_len : felt,
        metadata_uri : felt*,
        executor : felt,
        used_voting_strategies_len : felt,
        used_voting_strategies : felt*,
        user_voting_strategy_params_flat_len : felt,
        user_voting_strategy_params_flat : felt*,
        execution_params_len : felt,
        execution_params : felt*,
    ) -> ():
        alloc_locals

        # Verify that the caller is the authenticator contract.
        assert_valid_authenticator()

        # Verify that the executor address is one of the whitelisted addresses
        assert_valid_executor(executor)

        # The snapshot for the proposal is the current timestamp at proposal creation
        # We use a timestamp instead of a block number to define a snapshot so that the system can generalize to multi-chain
        # TODO: Need to consider what sort of guarantees we have on the timestamp returned being correct.
        let (snapshot_timestamp) = get_block_timestamp()
        let (delay) = Voting_voting_delay_store.read()

        let (_min_voting_duration) = Voting_min_voting_duration_store.read()
        let (_max_voting_duration) = Voting_max_voting_duration_store.read()

        # Define start_timestamp, min_end and max_end
        let start_timestamp = snapshot_timestamp + delay
        let min_end_timestamp = start_timestamp + _min_voting_duration
        let max_end_timestamp = start_timestamp + _max_voting_duration

        # Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
        let (user_voting_strategy_params_all : Immutable2DArray) = construct_array2d(
            user_voting_strategy_params_flat_len, user_voting_strategy_params_flat
        )

        let (voting_power) = get_cumulative_voting_power(
            snapshot_timestamp,
            proposer_address,
            used_voting_strategies_len,
            used_voting_strategies,
            user_voting_strategy_params_all,
            0,
        )

        # Verify that the proposer has enough voting power to trigger a proposal
        let (threshold) = Voting_proposal_threshold_store.read()
        let (is_lower) = uint256_lt(voting_power, threshold)
        if is_lower == 1:
            # Not enough voting power to create a proposal
            with_attr error_message("Not enough voting power"):
                assert 1 = 0
            end
        end

        # Hash the execution params
        # Storing arrays inside a struct is impossible so instead we just store a hash and then reconstruct the array in finalize_proposal
        let (execution_hash) = hash_array(execution_params_len, execution_params)

        let (_quorum) = Voting_quorum_store.read()

        # Create the proposal and its proposal id
        let proposal = Proposal(
            _quorum,
            snapshot_timestamp,
            start_timestamp,
            min_end_timestamp,
            max_end_timestamp,
            executor,
            execution_hash,
        )

        let (proposal_id) = Voting_next_proposal_nonce_store.read()

        # Store the proposal
        Voting_proposal_registry_store.write(proposal_id, proposal)

        # Emit event
        proposal_created.emit(
            proposal_id,
            proposer_address,
            proposal,
            metadata_uri_len,
            metadata_uri,
            execution_params_len,
            execution_params,
        )

        # Increase the proposal nonce
        Voting_next_proposal_nonce_store.write(proposal_id + 1)

        return ()
    end

    # Finalizes the proposal, counts the voting power, and send the corresponding result to the L1 executor contract
    @external
    func finalize_proposal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*,
        bitwise_ptr : BitwiseBuiltin*,
    }(proposal_id : felt, execution_params_len : felt, execution_params : felt*):
        alloc_locals

        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id)

        # Make sure proposal has not already been executed
        with_attr error_message("Proposal already executed"):
            assert has_been_executed = 0
        end

        let (proposal) = Voting_proposal_registry_store.read(proposal_id)
        with_attr error_message("Invalid proposal id"):
            # Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
            # be set to 0, hence the snapshot timestamp will be set to 0 too.
            assert_not_zero(proposal.snapshot_timestamp)
        end

        # Make sure proposal period has ended
        let (current_timestamp) = get_block_timestamp()
        with_attr error_message("Min voting period has not elapsed"):
            assert_le(proposal.min_end_timestamp, current_timestamp)
        end

        # Make sure execution params match the ones sent at proposal creation by checking that the hashes match
        let (recovered_hash) = hash_array(execution_params_len, execution_params)
        with_attr error_message("Invalid execution parameters"):
            assert recovered_hash = proposal.execution_hash
        end

        # Count votes for
        let (for) = Voting_vote_power_store.read(proposal_id, Choice.FOR)

        # Count votes against
        let (abstain) = Voting_vote_power_store.read(proposal_id, Choice.ABSTAIN)

        # Count votes against
        let (against) = Voting_vote_power_store.read(proposal_id, Choice.AGAINST)

        let (partial_power, overflow1) = uint256_add(for, abstain)

        let (total_power, overflow2) = uint256_add(partial_power, against)

        let _quorum = proposal.quorum
        let (is_lower_or_equal) = uint256_le(_quorum, total_power)

        # If overflow1 or overflow2 happened, then quorum has necessarily been reached because `quorum` is by definition smaller or equal to Uint256::MAX.
        # If `is_lower_or_equal` (meaning `_quorum` is smaller than `total_power`), then quorum has been reached (definition of quorum).
        # So if `overflow1 || overflow2 || is_lower_or_equal`, we have reached quorum. If we sum them and find `0`, then they're all equal to 0, which means
        # quorum has not been reached.
        with_attr error_message("Quorum has not been reached"):
            assert_not_zero(overflow1 + overflow2 + is_lower_or_equal)
        end

        # Set proposal outcome accordingly
        let (has_passed) = uint256_lt(against, for)

        if has_passed == 1:
            tempvar proposal_outcome = ProposalOutcome.ACCEPTED
        else:
            tempvar proposal_outcome = ProposalOutcome.REJECTED
        end

        let (is_valid) = Voting_executors_store.read(proposal.executor)
        if is_valid == 0:
            # Executor has been removed from the whitelist. Cancel this execution.
            tempvar proposal_outcome = ProposalOutcome.CANCELLED
        else:
            # Preventing revoked reference
            tempvar proposal_outcome = proposal_outcome
        end

        # Execute proposal Transactions
        # There are 2 situations:
        # 1) Starknet execution strategy - then txs are executed directly by this contract.
        # 2) Other execution strategy - then tx are executed by the specified execution strategy contract.

        if proposal.executor == 1:
            # Starknet execution strategy so we execute the proposal txs directly
            if proposal_outcome == ProposalOutcome.ACCEPTED:
                let (nonce) = Account.get_nonce()
                let (call_array_len, call_array, calldata_len, calldata) = decode_execution_params(
                    execution_params_len, execution_params
                )
                # We use unsafe execute as no signature verification is needed.
                let (response_len, response) = Account._unsafe_execute(
                    call_array_len, call_array, calldata_len, calldata, nonce
                )
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
                tempvar ecdsa_ptr = ecdsa_ptr
                tempvar bitwise_ptr = bitwise_ptr
            else:
                tempvar syscall_ptr = syscall_ptr
                tempvar pedersen_ptr = pedersen_ptr
                tempvar range_check_ptr = range_check_ptr
                tempvar ecdsa_ptr = ecdsa_ptr
                tempvar bitwise_ptr = bitwise_ptr
            end
        else:
            # Other execution strategy, so we forward the txs to the specified execution strategy contract.
            IExecutionStrategy.execute(
                contract_address=proposal.executor,
                proposal_outcome=proposal_outcome,
                execution_params_len=execution_params_len,
                execution_params=execution_params,
            )
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
            tempvar ecdsa_ptr = ecdsa_ptr
            tempvar bitwise_ptr = bitwise_ptr
        end

        # Flag this proposal as executed
        # This should not create re-entrency vulnerability because the message
        # executor is a whitelisted address. If we set this flag BEFORE the call
        # to the executor, we could have a malicious attacker sending some random
        # invalid execution_params and cancel out the vote.
        Voting_executed_proposals_store.write(proposal_id, 1)

        return ()
    end

    # Cancels the proposal. Only callable by the controller.
    @external
    func cancel_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        proposal_id : felt, execution_params_len : felt, execution_params : felt*
    ):
        alloc_locals

        Ownable.assert_only_owner()

        let (has_been_executed) = Voting_executed_proposals_store.read(proposal_id)

        # Make sure proposal has not already been executed
        with_attr error_message("Proposal already executed"):
            assert has_been_executed = 0
        end

        let (proposal) = Voting_proposal_registry_store.read(proposal_id)
        with_attr error_message("Invalid proposal id"):
            # Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
            # be set to 0, hence the snapshot timestamp will be set to 0 too.
            assert_not_zero(proposal.snapshot_timestamp)
        end

        let proposal_outcome = ProposalOutcome.CANCELLED

        IExecutionStrategy.execute(
            contract_address=proposal.executor,
            proposal_outcome=proposal_outcome,
            execution_params_len=execution_params_len,
            execution_params=execution_params,
        )

        # Flag this proposal as executed
        # This should not create re-entrency vulnerability because the message
        # executor is a whitelisted address. If we set this flag BEFORE the call
        # to the executor, we could have a malicious attacker sending some random
        # invalid execution_params and cancel out the vote.
        Voting_executed_proposals_store.write(proposal_id, 1)

        return ()
    end

    #
    # View functions
    #

    @view
    func get_vote_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        voter_address : Address, proposal_id : felt
    ) -> (vote : Vote):
        return Voting_vote_registry_store.read(proposal_id, voter_address)
    end

    @view
    func get_proposal_info{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
    }(proposal_id : felt) -> (proposal_info : ProposalInfo):
        let (proposal) = Voting_proposal_registry_store.read(proposal_id)

        let (_power_against) = Voting_vote_power_store.read(proposal_id, Choice.AGAINST)
        let (_power_for) = Voting_vote_power_store.read(proposal_id, Choice.FOR)
        let (_power_abstain) = Voting_vote_power_store.read(proposal_id, Choice.ABSTAIN)
        return (
            ProposalInfo(proposal=proposal, power_for=_power_for, power_against=_power_against, power_abstain=_power_abstain),
        )
    end
end

#
#  Internal Functions
#

func unchecked_add_executors{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to_add_len : felt, to_add : felt*
):
    if to_add_len == 0:
        return ()
    else:
        Voting_executors_store.write(to_add[0], 1)

        unchecked_add_executors(to_add_len - 1, &to_add[1])
        return ()
    end
end

func unchecked_remove_executors{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(to_remove_len : felt, to_remove : felt*):
    if to_remove_len == 0:
        return ()
    else:
        Voting_executors_store.write(to_remove[0], 0)

        unchecked_remove_executors(to_remove_len - 1, &to_remove[1])
        return ()
    end
end

func unchecked_add_voting_strategies{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(to_add_len : felt, to_add : felt*, params_all : Immutable2DArray, index : felt):
    alloc_locals
    if to_add_len == 0:
        return ()
    else:
        Voting_voting_strategies_store.write(to_add[0], 1)

        # Extract voting params for the voting strategy
        let (params_len, params) = get_sub_array(params_all, index)

        # We store the length of the voting strategy params array at index zero
        Voting_voting_strategy_params_store.write(to_add[0], 0, params_len)

        # The following elements are the actual params
        unchecked_add_voting_strategy_params(to_add[0], params_len, params, 1)

        unchecked_add_voting_strategies(to_add_len - 1, &to_add[1], params_all, index + 1)
        return ()
    end
end

func unchecked_add_voting_strategy_params{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(to_add : felt, params_len : felt, params : felt*, index : felt):
    if params_len == 0:
        # List is empty
        return ()
    else:
        # Store voting parameter
        Voting_voting_strategy_params_store.write(to_add, index, params[0])

        unchecked_add_voting_strategy_params(to_add, params_len - 1, &params[1], index + 1)
        return ()
    end
end

func unchecked_remove_voting_strategies{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(to_remove_len : felt, to_remove : felt*):
    if to_remove_len == 0:
        return ()
    else:
        Voting_voting_strategies_store.write(to_remove[0], 0)

        # The length of the voting strategy params is stored at index zero
        let (params_len) = Voting_voting_strategy_params_store.read(to_remove[0], 0)

        Voting_voting_strategy_params_store.write(to_remove[0], 0, 0)

        # Removing voting strategy params
        unchecked_remove_voting_strategy_params(to_remove[0], params_len, 1)

        unchecked_remove_voting_strategies(to_remove_len - 1, &to_remove[1])
        return ()
    end
end

func unchecked_remove_voting_strategy_params{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(to_remove : felt, params_len : felt, index : felt):
    if params_len == 0:
        # List is empty
        return ()
    end
    if index == params_len + 1:
        # All params have been removed from the array
        return ()
    end
    # Remove voting parameter
    Voting_voting_strategy_params_store.write(to_remove, index, 0)

    unchecked_remove_voting_strategy_params(to_remove, params_len, index + 1)
    return ()
end

func unchecked_add_authenticators{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(to_add_len : felt, to_add : felt*):
    if to_add_len == 0:
        return ()
    else:
        Voting_authenticators_store.write(to_add[0], 1)

        unchecked_add_authenticators(to_add_len - 1, &to_add[1])
        return ()
    end
end

func unchecked_remove_authenticators{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(to_remove_len : felt, to_remove : felt*):
    if to_remove_len == 0:
        return ()
    else:
        Voting_authenticators_store.write(to_remove[0], 0)

        unchecked_remove_authenticators(to_remove_len - 1, &to_remove[1])
    end
    return ()
end

# Throws if the caller address is not a member of the set of whitelisted authenticators (stored in the `authenticators` mapping)
func assert_valid_authenticator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ):
    let (caller_address) = get_caller_address()
    let (is_valid) = Voting_authenticators_store.read(caller_address)

    # Ensure it has been initialized
    with_attr error_message("Invalid authenticator"):
        assert_not_zero(is_valid)
    end

    return ()
end

# Throws if `executor` is not a member of the set of whitelisted executors (stored in the `executors` mapping)
func assert_valid_executor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    executor : felt
):
    let (is_valid) = Voting_executors_store.read(executor)

    with_attr error_message("Invalid executor"):
        assert is_valid = 1
    end

    return ()
end

# Computes the cumulated voting power of a user by iterating over the voting strategies of `used_voting_strategies`.
# TODO: In the future we will need to transition to an array of `voter_address` because they might be different for different voting strategies.
func get_cumulative_voting_power{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_timestamp : felt,
    voter_address : Address,
    used_voting_strategies_len : felt,
    used_voting_strategies : felt*,
    user_voting_strategy_params_all : Immutable2DArray,
    index : felt,
) -> (voting_power : Uint256):
    alloc_locals

    if used_voting_strategies_len == 0:
        # Reached the end, stop iteration
        return (Uint256(0, 0))
    end

    let voting_strategy = used_voting_strategies[0]

    let (is_valid) = Voting_voting_strategies_store.read(voting_strategy)

    with_attr error_message("Invalid voting strategy"):
        assert is_valid = 1
    end

    # Extract voting params array for the voting strategy specified by the index
    let (user_voting_strategy_params_len, user_voting_strategy_params) = get_sub_array(
        user_voting_strategy_params_all, index
    )

    # Initialize empty array to store voting params
    let (voting_strategy_params : felt*) = alloc()

    # Check that voting strategy params exist by the length which is stored in the first element of the array
    let (voting_strategy_params_len) = Voting_voting_strategy_params_store.read(voting_strategy, 0)

    let (voting_strategy_params_len, voting_strategy_params) = get_voting_strategy_params(
        voting_strategy, voting_strategy_params_len, voting_strategy_params, 1
    )

    let (user_voting_power) = IVotingStrategy.get_voting_power(
        contract_address=voting_strategy,
        timestamp=current_timestamp,
        voter_address=voter_address,
        params_len=voting_strategy_params_len,
        params=voting_strategy_params,
        user_params_len=user_voting_strategy_params_len,
        user_params=user_voting_strategy_params,
    )

    let (additional_voting_power) = get_cumulative_voting_power(
        current_timestamp,
        voter_address,
        used_voting_strategies_len - 1,
        &used_voting_strategies[1],
        user_voting_strategy_params_all,
        index + 1,
    )

    let (voting_power, overflow) = uint256_add(user_voting_power, additional_voting_power)

    with_attr error_message("Overflow while computing voting power"):
        assert overflow = 0
    end

    return (voting_power)
end

# Function to reconstruct voting param array for voting strategy specified
func get_voting_strategy_params{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _voting_strategy_contract : felt,
    voting_strategy_params_len : felt,
    voting_strategy_params : felt*,
    index : felt,
) -> (voting_strategy_params_len : felt, voting_strategy_params : felt*):
    # The are no parameters so we just return an empty array
    if voting_strategy_params_len == 0:
        return (0, voting_strategy_params)
    end

    let (voting_strategy_param) = Voting_voting_strategy_params_store.read(
        _voting_strategy_contract, index
    )
    assert voting_strategy_params[index - 1] = voting_strategy_param

    # All parameters have been added to the array so we can return it
    if index == voting_strategy_params_len:
        return (voting_strategy_params_len, voting_strategy_params)
    end

    let (voting_strategy_params_len, voting_strategy_params) = get_voting_strategy_params(
        _voting_strategy_contract, voting_strategy_params_len, voting_strategy_params, index + 1
    )
    return (voting_strategy_params_len, voting_strategy_params)
end

# Decodes an array into the data required to perform a set of calls according to the OZ account standard
func decode_execution_params{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    execution_params_len : felt, execution_params : felt*
) -> (call_array_len : felt, call_array : AccountCallArray*, calldata_len : felt, calldata : felt*):
    assert_nn_le(4, execution_params_len)  # Min execution params length is 4 (corresponding to 1 tx with no calldata)
    let call_array_len = (execution_params[0] - 1) / 4  # Number of calls in the proposal payload
    let call_array = cast(&execution_params[1], AccountCallArray*)
    let calldata_len = execution_params_len - execution_params[0]
    let calldata = &execution_params[execution_params[0]]
    return (call_array_len, call_array, calldata_len, calldata)
end
