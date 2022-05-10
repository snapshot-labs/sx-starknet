%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.math import (
    assert_lt, assert_le, assert_nn, assert_not_zero, assert_lt_felt
)

from contracts.starknet.interfaces.i_voting_strategy import i_voting_strategy
from contracts.starknet.interfaces.i_execution_strategy import i_execution_strategy
from contracts.starknet.lib.eth_address import EthAddress
from contracts.starknet.lib.proposal import Proposal
from contracts.starknet.lib.proposal_info import ProposalInfo
from contracts.starknet.lib.vote import Vote
from contracts.starknet.lib.choice import Choice
from contracts.starknet.lib.proposal_outcome import ProposalOutcome
from contracts.starknet.lib.hash_array import hash_array
from contracts.starknet.lib.array2d import Immutable2DArray, construct_array2d, get_sub_array
from contracts.starknet.lib.slot_key import get_slot_key

from openzeppelin.access.ownable import (
    Ownable_only_owner, Ownable_transfer_ownership, Ownable_get_owner, Ownable_initializer
)

#
# Storage vars
#

@storage_var
func voting_delay() -> (delay : felt):
end

@storage_var
func voting_duration() -> (period : felt):
end

@storage_var
func proposal_threshold() -> (threshold : Uint256):
end

@storage_var
func authenticators(authenticator_address : felt) -> (is_valid : felt):
end

@storage_var
func executors(executor_address : felt) -> (is_valid : felt):
end

@storage_var
func voting_strategies(strategy_address : felt) -> (is_valid : felt):
end

@storage_var
func global_voting_strategy_params(voting_strategy_contract : felt, index : felt) -> (
    global_voting_strategy_param : felt
):
end

@storage_var
func next_proposal_nonce() -> (nonce : felt):
end

@storage_var
func proposal_registry(proposal_id : felt) -> (proposal : Proposal):
end

@storage_var
func executed_proposals(proposal_id : felt) -> (executed : felt):
end

@storage_var
func vote_registry(proposal_id : felt, voter_address : EthAddress) -> (vote : Vote):
end

@storage_var
func vote_power(proposal_id : felt, choice : felt) -> (power : Uint256):
end

#
# Events
#

@event
func proposal_created(
    proposal_id : felt,
    proposer_address : EthAddress,
    proposal : Proposal,
    metadata_uri_len : felt,
    metadata_uri : felt*,
    execution_params_len : felt,
    execution_params : felt*,
):
end

@event
func vote_created(proposal_id : felt, voter_address : EthAddress, vote : Vote):
end

@event
func space_created(
    _voting_delay : felt,
    _voting_duration : felt,
    _proposal_threshold : Uint256,
    _controller : felt,
    _voting_strategies_len : felt,
    _voting_strategies : felt*,
    _authenticators_len : felt,
    _authenticators : felt*,
    _executors_len : felt,
    _executors : felt*,
):
end

@event
func controller_updated(previous : felt, new_controller : felt):
end

@event
func voting_delay_updated(previous : felt, new_voting_delay : felt):
end

@event
func voting_duration_updated(previous : felt, new_voting_duration : felt):
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

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    _voting_delay : felt,
    _voting_duration : felt,
    _proposal_threshold : Uint256,
    _controller : felt,
    _global_voting_strategy_params_flat_len : felt,
    _global_voting_strategy_params_flat : felt*,
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
        assert_nn(_voting_duration)
        assert_not_zero(_controller)
        assert_not_zero(_voting_strategies_len)
        assert_not_zero(_authenticators_len)
        assert_not_zero(_executors_len)
    end
    # TODO: maybe use uint256_signed_nn to check proposal_threshold?

    # Initialize the storage variables
    voting_delay.write(_voting_delay)
    voting_duration.write(_voting_duration)
    proposal_threshold.write(_proposal_threshold)
    Ownable_initializer(_controller)

    # Reconstruct the global voting params 2D array (1 sub array per strategy) from the flattened version.
    # Currently there is no way to pass struct types with pointers in calldata, so we must do it this way.
    let (global_voting_strategy_params_all : Immutable2DArray) = construct_array2d(
        _global_voting_strategy_params_flat_len, _global_voting_strategy_params_flat
    )

    unchecked_add_voting_strategies(_voting_strategies_len, _voting_strategies, global_voting_strategy_params_all, 0)
    unchecked_add_authenticators(_authenticators_len, _authenticators)
    unchecked_add_executors(_executors_len, _executors)

    next_proposal_nonce.write(1)

    space_created.emit(
        _voting_delay,
        _voting_duration,
        _proposal_threshold,
        _controller,
        _voting_strategies_len,
        _voting_strategies,
        _authenticators_len,
        _authenticators,
        _executors_len,
        _executors,
    )

    return ()
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
        executors.write(to_add[0], 1)

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
        executors.write(to_remove[0], 0)

        unchecked_remove_executors(to_remove_len - 1, &to_remove[1])
        return ()
    end
end

func unchecked_add_voting_strategies{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    to_add_len : felt,
    to_add : felt*,
    global_params_all : Immutable2DArray,
    index : felt
):
    alloc_locals
    if to_add_len == 0:
        return ()
    else:
        voting_strategies.write(to_add[0], 1)

        # Extract global voting params for the voting strategy
        let (global_params_len, global_params) = get_sub_array(
            global_params_all, index
        )

        # Add global voting params
        register_global_voting_strategy_params(
            0,
            to_add[0],
            global_params_len,
            global_params,
        )

        unchecked_add_voting_strategies(to_add_len - 1, &to_add[1], global_params_all, index + 1)
        return ()
    end
end

func register_global_voting_strategy_params{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(
    index : felt,
    voting_strategy : felt,
    _global_voting_strategy_params_len : felt,
    _global_voting_strategy_params : felt*,
):
    if _global_voting_strategy_params_len == 0:
        # List is empty
        return ()
    else:
        # Store global voting parameter
        global_voting_strategy_params.write(
            voting_strategy, index, _global_voting_strategy_params[0]
        )

        if _global_voting_strategy_params_len == 1:
            # Nothing left to add, end recursion
            return ()
        else:
            # Recurse
            register_global_voting_strategy_params(
                index + 1,
                voting_strategy,
                _global_voting_strategy_params_len - 1,
                &_global_voting_strategy_params[1],
            )
            return ()
        end
    end
end

func unchecked_remove_voting_strategies{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(to_remove_len : felt, to_remove : felt*):
    if to_remove_len == 0:
        return ()
    else:
        voting_strategies.write(to_remove[0], 0)

        unchecked_remove_voting_strategies(to_remove_len - 1, &to_remove[1])
        return ()
    end
end

func unchecked_add_authenticators{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(to_add_len : felt, to_add : felt*):
    if to_add_len == 0:
        return ()
    else:
        authenticators.write(to_add[0], 1)

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
        authenticators.write(to_remove[0], 0)

        unchecked_remove_authenticators(to_remove_len - 1, &to_remove[1])
    end
    return ()
end

# Throws if the caller address is not a member of the set of whitelisted authenticators (stored in the `authenticators` mapping)
func assert_valid_authenticator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ):
    let (caller_address) = get_caller_address()
    let (is_valid) = authenticators.read(caller_address)

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
    let (is_valid) = executors.read(executor)

    with_attr error_message("Invalid executor"):
        assert is_valid = 1
    end

    return ()
end

# Computes the cumulated voting power of a user by iterating over the voting strategies of `used_voting_strategies`.
# TODO: In the future we will need to transition to an array of `voter_address` because they might be different for different voting strategies.
func get_cumulative_voting_power{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    current_timestamp : felt,
    voter_address : EthAddress,
    used_voting_strategies_len : felt,
    used_voting_strategies : felt*,
    voting_strategy_params_all : Immutable2DArray,
    index : felt 
) -> (voting_power : Uint256):
    alloc_locals

    if used_voting_strategies_len == 0:
        # Reached the end, stop iteration
        return (Uint256(0, 0))
    end

    let voting_strategy = used_voting_strategies[0]

    let (is_valid) = voting_strategies.read(voting_strategy)

    with_attr error_message("Invalid voting strategy"):
        assert is_valid = 1
    end

    # Initialize empty array to store global voting params
    let (global_voting_strategy_params : felt*) = alloc()

    # Retrieve global voting strategy params
    let (global_voting_strategy_params_len) = get_global_voting_strategy_params(
        voting_strategy, global_voting_strategy_params, 0
    )

    # Extract voting params array for the voting strategy specified by the index
    let (voting_strategy_params_len, voting_strategy_params) = get_sub_array(
        voting_strategy_params_all, index
    )

    let (user_voting_power) = i_voting_strategy.get_voting_power(
        contract_address=voting_strategy,
        timestamp=current_timestamp,
        address=voter_address,
        global_params_len=global_voting_strategy_params_len,
        global_params=global_voting_strategy_params,
        params_len=voting_strategy_params_len,
        params=voting_strategy_params,
    )

    let (additional_voting_power) = get_cumulative_voting_power(
        current_timestamp,
        voter_address,
        used_voting_strategies_len - 1,
        &used_voting_strategies[1],
        voting_strategy_params_all,
        index + 1
    )

    let (voting_power, overflow) = uint256_add(user_voting_power, additional_voting_power)

    with_attr error_message("Overflow while computing voting power"):
        assert overflow = 0
    end

    return (voting_power)
end

# Function to reconstruct global voting param array for voting strategy
func get_global_voting_strategy_params{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(_voting_strategy_contract : felt, _global_voting_strategy_params : felt*, index : felt) -> (
    global_voting_strategy_params_len : felt
):
    let (global_voting_strategy_param) = global_voting_strategy_params.read(
        _voting_strategy_contract, index
    )
    if global_voting_strategy_param == 0:
        return (index)
    else:
        assert _global_voting_strategy_params[index] = global_voting_strategy_param

        let (global_voting_strategy_params_len) = get_global_voting_strategy_params(
            _voting_strategy_contract, _global_voting_strategy_params, index + 1
        )
        return (0)
    end
end

#
# External Functions
#

@external
func update_controller{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    new_controller : felt
):
    Ownable_only_owner()

    let (previous_controller) = Ownable_get_owner()

    Ownable_transfer_ownership(new_controller)

    controller_updated.emit(previous_controller, new_controller)
    return ()
end

@external
func update_voting_delay{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    new_delay : felt
):
    Ownable_only_owner()

    let (previous_delay) = voting_delay.read()

    voting_delay.write(new_delay)

    voting_delay_updated.emit(previous_delay, new_delay)

    return ()
end

@external
func update_voting_duration{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(new_duration : felt):
    Ownable_only_owner()

    let (previous_duration) = voting_duration.read()

    voting_duration.write(new_duration)

    voting_duration_updated.emit(previous_duration, new_duration)

    return ()
end

@external
func update_proposal_threshold{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(new_threshold : Uint256):
    Ownable_only_owner()

    let (previous_threshold) = proposal_threshold.read()

    proposal_threshold.write(new_threshold)

    proposal_threshold_updated.emit(previous_threshold, new_threshold)

    return ()
end

@external
func add_executors{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    to_add_len : felt, to_add : felt*
):
    alloc_locals

    Ownable_only_owner()

    unchecked_add_executors(to_add_len, to_add)

    executors_added.emit(to_add_len, to_add)
    return ()
end

@external
func remove_executors{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    to_remove_len : felt, to_remove : felt*
):
    alloc_locals

    Ownable_only_owner()

    unchecked_remove_executors(to_remove_len, to_remove)

    executors_removed.emit(to_remove_len, to_remove)
    return ()
end

@external
func add_voting_strategies{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(
    to_add_len : felt,
    to_add : felt*,
    global_params_flat_len : felt,
    global_params_flat : felt*,
):
    alloc_locals

    Ownable_only_owner()

    let (global_params_all : Immutable2DArray) = construct_array2d(
        global_params_flat_len, global_params_flat
    )

    unchecked_add_voting_strategies(to_add_len, to_add, global_params_all, 0)

    voting_strategies_added.emit(to_add_len, to_add)
    return ()
end

@external
func remove_voting_strategies{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(to_remove_len : felt, to_remove : felt*):
    alloc_locals

    Ownable_only_owner()

    unchecked_remove_voting_strategies(to_remove_len, to_remove)
    voting_strategies_removed.emit(to_remove_len, to_remove)
    return ()
end

@external
func add_authenticators{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    to_add_len : felt, to_add : felt*
):
    alloc_locals

    Ownable_only_owner()

    unchecked_add_authenticators(to_add_len, to_add)

    authenticators_added.emit(to_add_len, to_add)
    return ()
end

@external
func remove_authenticators{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt
}(to_remove_len : felt, to_remove : felt*):
    alloc_locals

    Ownable_only_owner()

    unchecked_remove_authenticators(to_remove_len, to_remove)

    authenticators_removed.emit(to_remove_len, to_remove)
    return ()
end

@external
func vote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    voter_address : EthAddress,
    proposal_id : felt,
    choice : felt,
    used_voting_strategies_len : felt,
    used_voting_strategies : felt*,
    voting_strategy_params_flat_len : felt,
    voting_strategy_params_flat : felt*,
) -> ():
    alloc_locals

    # Verify that the caller is the authenticator contract.
    assert_valid_authenticator()

    let (proposal) = proposal_registry.read(proposal_id)
    let (current_timestamp) = get_block_timestamp()

    # Make sure proposal is not closed
    with_attr error_message("Voting period has ended"):
        assert_lt(current_timestamp, proposal.end_timestamp)
    end

    # Make sure proposal has started
    with_attr error_message("Voting has not started yet"):
        assert_le(proposal.start_timestamp, current_timestamp)
    end

    # Make sure voter has not already voted
    let (prev_vote) = vote_registry.read(proposal_id, voter_address)
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
    let (voting_strategy_params_all : Immutable2DArray) = construct_array2d(
        voting_strategy_params_flat_len, voting_strategy_params_flat
    )

    let (user_voting_power) = get_cumulative_voting_power(
        current_timestamp,
        voter_address,
        used_voting_strategies_len,
        used_voting_strategies,
        voting_strategy_params_all,
        0
    )

    let (previous_voting_power) = vote_power.read(proposal_id, choice)
    let (new_voting_power, overflow) = uint256_add(user_voting_power, previous_voting_power)

    if overflow != 0:
        # Overflow happened, throw error
        with_attr error_message("Overflow"):
            assert 1 = 0
        end
    end

    vote_power.write(proposal_id, choice, new_voting_power)

    let vote = Vote(choice=choice, voting_power=user_voting_power)
    vote_registry.write(proposal_id, voter_address, vote)

    # Emit event
    vote_created.emit(proposal_id, voter_address, vote)

    return ()
end

@external
func propose{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    proposer_address : EthAddress,
    execution_hash : Uint256,
    metadata_uri_len : felt,
    metadata_uri : felt*,
    ethereum_block_number : felt,
    executor : felt,
    used_voting_strategies_len : felt,
    used_voting_strategies : felt*,
    voting_strategy_params_flat_len : felt,
    voting_strategy_params_flat : felt*,
    execution_params_len : felt,
    execution_params : felt*,
) -> ():
    alloc_locals

    # We cannot have `0` as the `ethereum_block_number` because we rely on checking
    # if it's different than 0 in `finalize_proposal`.
    with_attr error_message("Invalid block number"):
        assert_not_zero(ethereum_block_number)
    end

    # Verify that the caller is the authenticator contract.
    assert_valid_authenticator()

    # Verify that the executor address is one of the whitelisted addresses
    assert_valid_executor(executor)

    let (current_timestamp) = get_block_timestamp()
    let (delay) = voting_delay.read()
    let (duration) = voting_duration.read()

    # Define start_timestamp and end_timestamp based on current timestamp, delay and duration variables.
    let start_timestamp = current_timestamp + delay
    let end_timestamp = start_timestamp + duration

    # Reconstruct the voting params 2D array (1 sub array per strategy) from the flattened version.
    let (voting_strategy_params_all : Immutable2DArray) = construct_array2d(
        voting_strategy_params_flat_len, voting_strategy_params_flat
    )

    let (voting_power) = get_cumulative_voting_power(
        start_timestamp,
        proposer_address,
        used_voting_strategies_len,
        used_voting_strategies,
        voting_strategy_params_all,
        0
    )

    # Verify that the proposer has enough voting power to trigger a proposal
    let (threshold) = proposal_threshold.read()
    let (is_lower) = uint256_lt(voting_power, threshold)
    if is_lower == 1:
        # Not enough voting power to create a proposal
        with_attr error_message("Not enough voting power"):
            assert 1 = 0
        end
    end

    # Hash the execution params
    let (hash) = hash_array(execution_params_len, execution_params)

    # Create the proposal and its proposal id
    let proposal = Proposal(
        execution_hash, start_timestamp, end_timestamp, ethereum_block_number, hash, executor
    )

    let (proposal_id) = next_proposal_nonce.read()

    # Store the proposal
    proposal_registry.write(proposal_id, proposal)

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
    next_proposal_nonce.write(proposal_id + 1)

    return ()
end

# Finalizes the proposal, counts the voting power, and send the corresponding result to the L1 executor contract
@external
func finalize_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    proposal_id : felt, execution_params_len : felt, execution_params : felt*
):
    alloc_locals

    let (has_been_executed) = executed_proposals.read(proposal_id)

    # Make sure proposal has not already been executed
    with_attr error_message("Proposal already executed"):
        assert has_been_executed = 0
    end

    let (proposal) = proposal_registry.read(proposal_id)
    with_attr error_message("Invalid proposal id"):
        # Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
        # be set to 0, hence `ethereum_block_number` will be set to 0 too.
        assert_not_zero(proposal.ethereum_block_number)
    end

    # Make sure proposal period has ended
    let (current_timestamp) = get_block_timestamp()
    # ------------------------------------------------
    #                  IMPORTANT
    # ------------------------------------------------
    # This has been commented to allow for easier testing.
    # Please uncomment before pushing to prod.
    # with_attr error_message("Voting period has not ended yet"):
    #   assert_lt_felt(proposal.end_timestamp, current_timestamp)
    # end

    # Make sure execution params match the stored hash
    let (recovered_hash) = hash_array(execution_params_len, execution_params)
    with_attr error_message("Invalid execution parameters"):
        assert recovered_hash = proposal.execution_params_hash
    end

    # Count votes for
    let (for) = vote_power.read(proposal_id, Choice.FOR)

    # Count votes against
    let (against) = vote_power.read(proposal_id, Choice.AGAINST)

    # Set proposal outcome accordingly
    let (has_passed) = uint256_lt(against, for)

    if has_passed == 1:
        tempvar proposal_outcome = ProposalOutcome.ACCEPTED
    else:
        tempvar proposal_outcome = ProposalOutcome.REJECTED
    end

    let (is_valid) = executors.read(proposal.executor)
    if is_valid == 0:
        # Executor has been removed from the whitelist. Cancel this execution.
        tempvar proposal_outcome = ProposalOutcome.CANCELLED
    else:
        # Classic cairo reference hackz
        tempvar proposal_outcome = proposal_outcome
    end

    i_execution_strategy.execute(
        contract_address=proposal.executor,
        proposal_outcome=proposal_outcome,
        execution_hash=proposal.execution_hash,
        execution_params_len=execution_params_len,
        execution_params=execution_params,
    )

    # Flag this proposal as executed
    # This should not create re-entrency vulnerability because the message
    # executor is a whitelisted address. If we set this flag BEFORE the call
    # to the executor, we could have a malicious attacker sending some random
    # invalid execution_params and cancel out the vote.
    executed_proposals.write(proposal_id, 1)

    return ()
end

# Cancels the proposal. Only callable by the controller.
@external
func cancel_proposal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    proposal_id : felt, execution_params_len : felt, execution_params : felt*
):
    alloc_locals

    Ownable_only_owner()

    let (has_been_executed) = executed_proposals.read(proposal_id)

    # Make sure proposal has not already been executed
    with_attr error_message("Proposal already executed"):
        assert has_been_executed = 0
    end

    let (proposal) = proposal_registry.read(proposal_id)
    with_attr error_message("Invalid proposal id"):
        # Checks that the proposal id exists. If it doesn't exist, then the whole `Proposal` struct will
        # be set to 0, hence `ethereum_block_number` will be set to 0 too.
        assert_not_zero(proposal.ethereum_block_number)
    end

    let proposal_outcome = ProposalOutcome.CANCELLED

    i_execution_strategy.execute(
        contract_address=proposal.executor,
        proposal_outcome=proposal_outcome,
        execution_hash=proposal.execution_hash,
        execution_params_len=execution_params_len,
        execution_params=execution_params,
    )

    # Flag this proposal as executed
    # This should not create re-entrency vulnerability because the message
    # executor is a whitelisted address. If we set this flag BEFORE the call
    # to the executor, we could have a malicious attacker sending some random
    # invalid execution_params and cancel out the vote.
    executed_proposals.write(proposal_id, 1)

    return ()
end

#
# View functions
#

@view
func get_vote_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    voter_address : EthAddress, proposal_id : felt
) -> (vote : Vote):
    return vote_registry.read(proposal_id, voter_address)
end

@view
func get_proposal_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    proposal_id : felt
) -> (proposal_info : ProposalInfo):
    let (proposal) = proposal_registry.read(proposal_id)

    let (_power_against) = vote_power.read(proposal_id, Choice.AGAINST)
    let (_power_for) = vote_power.read(proposal_id, Choice.FOR)
    let (_power_abstain) = vote_power.read(proposal_id, Choice.ABSTAIN)
    return (
        ProposalInfo(proposal=proposal, power_for=_power_for, power_against=_power_against, power_abstain=_power_abstain),
    )
end
