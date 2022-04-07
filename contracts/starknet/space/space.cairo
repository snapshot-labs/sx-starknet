%lang starknet

from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_le, assert_nn, assert_not_zero
from contracts.starknet.strategies.interface import IVotingStrategy
from contracts.starknet.lib.eth_address import EthAddress
from contracts.starknet.lib.proposal import Proposal
from contracts.starknet.lib.proposal_info import ProposalInfo
from contracts.starknet.lib.vote import Vote
from contracts.starknet.lib.choice import Choice
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt

@storage_var
func voting_delay() -> (delay : felt):
end

@storage_var
func voting_period() -> (period : felt):
end

@storage_var
func proposal_threshold() -> (threshold : Uint256):
end

@storage_var
func voting_strategies(voting_strategy_contract : felt) -> (is_valid : felt):
end

@storage_var
func authenticators(authenticator_address : felt) -> (is_valid : felt):
end

@storage_var
func next_proposal_nonce() -> (nonce : felt):
end

@storage_var
func proposal_registry(proposal_id : felt) -> (proposal : Proposal):
end

@storage_var
func vote_registry(proposal_id : felt, voter_address : EthAddress) -> (vote : Vote):
end

@storage_var
func vote_power(proposal_id : felt, choice : felt) -> (power : Uint256):
end

@event
func proposal_created(
        proposal_id : felt, proposer_address : EthAddress, proposal : Proposal,
        metadata_uri_len : felt, metadata_uri : felt*):
end

@event
func vote_created(proposal_id : felt, voter_address : EthAddress, vote : Vote):
end

# Throws if the caller address is not identical to the authenticator address (stored in the `authenticator` variable)
func assert_valid_authenticator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ):
    let (caller_address) = get_caller_address()
    let (is_valid) = authenticators.read(caller_address)

    # Ensure it has been initialized
    assert_not_zero(is_valid)

    return ()
end

# Throws if the caller address is not identical to the authenticator address (stored in the `authenticator` variable)
func assert_valid_voting_strategy{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        voting_strategy_contract : felt):
    let (is_valid) = voting_strategies.read(voting_strategy_contract)

    # Ensure it has been initialized
    assert_not_zero(is_valid)

    return ()
end

func register_voting_strategies{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _voting_strategies_len : felt, _voting_strategies : felt*):
    if _voting_strategies_len == 0:
        # List is empty
        return ()
    else:
        # Add voting strategy
        voting_strategies.write(_voting_strategies[0], 1)

        if _voting_strategies_len == 1:
            # Nothing left to add, end recursion
            return ()
        else:
            # Recurse
            register_voting_strategies(_voting_strategies_len - 1, &_voting_strategies[1])
            return ()
        end
    end
end

func register_authenticators{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _authenticators_len : felt, _authenticators : felt*):
    if _authenticators_len == 0:
        # List is empty
        return ()
    else:
        # Add voting strategy
        authenticators.write(_authenticators[0], 1)

        if _authenticators_len == 1:
            # Nothing left to add, end recursion
            return ()
        else:
            # Recurse
            register_authenticators(_authenticators_len - 1, &_authenticators[1])
            return ()
        end
    end
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        _voting_delay : felt, _voting_period : felt, _proposal_threshold : Uint256,
        _voting_strategies_len : felt, _voting_strategies : felt*, _authenticators_len : felt,
        _authenticators : felt*):
    # Sanity checks
    assert_nn(_voting_delay)
    assert_nn(_voting_period)
    assert_not_zero(_voting_strategies_len)
    assert_not_zero(_authenticators_len)
    # TODO: maybe use uint256_signed_nn to check proposal_threshold?

    # Initialize the storage variables
    voting_delay.write(_voting_delay)
    voting_period.write(_voting_period)
    proposal_threshold.write(_proposal_threshold)

    register_voting_strategies(_voting_strategies_len, _voting_strategies)
    register_authenticators(_authenticators_len, _authenticators)

    next_proposal_nonce.write(1)

    return ()
end

@external
func vote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        voting_strategy_contract : felt, voter_address : EthAddress, proposal_id : felt,
        choice : felt, params_len : felt, params : felt*) -> ():
    alloc_locals

    # Verify that the caller is the authenticator contract.
    assert_valid_authenticator()
    assert_valid_voting_strategy(voting_strategy_contract)

    let (proposal) = proposal_registry.read(proposal_id)
    let (current_timestamp) = get_block_timestamp()

    # Make sure proposal is not closed
    assert_lt(current_timestamp, proposal.end_timestamp)

    # Make sure proposal has started
    assert_le(proposal.start_timestamp, current_timestamp)

    # Make sure voter has not already voted
    let (prev_vote) = vote_registry.read(proposal_id, voter_address)
    if prev_vote.choice != 0:
        # Voter has already voted!
        assert 1 = 0
    end

    let (user_voting_power) = IVotingStrategy.get_voting_power(
        contract_address=voting_strategy_contract,
        timestamp=current_timestamp,
        address=voter_address,
        params_len=params_len,
        params=params)

    # Make sure `choice` is a valid choice
    assert_le(Choice.FOR, choice)
    assert_le(choice, Choice.ABSTAIN)

    let (previous_voting_power) = vote_power.read(proposal_id, choice)
    let (new_voting_power, carry) = uint256_add(user_voting_power, previous_voting_power)

    if carry != 0:
        # Overflow happened, throw error
        assert 1 = 0
    end

    vote_power.write(proposal_id, choice, new_voting_power)

    let vote = Vote(choice=choice, voting_power=user_voting_power)
    vote_registry.write(proposal_id, voter_address, vote)

    # Emit event
    vote_created.emit(proposal_id, voter_address, vote)

    return ()
end

# TODO: execution_hash should be of type Hash and metadata_uri of type felt* (string)
@external
func propose{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        voting_strategy_contract : felt, proposer_address : EthAddress, execution_hash : felt,
        metadata_uri_len : felt, metadata_uri : felt*, ethereum_block_number : felt,
        params_len : felt, params : felt*) -> ():
    alloc_locals

    # Verify that the caller is the authenticator contract.
    assert_valid_authenticator()
    assert_valid_voting_strategy(voting_strategy_contract)

    let (current_timestamp) = get_block_timestamp()
    let (delay) = voting_delay.read()
    let (duration) = voting_period.read()

    # Define start_timestamp and end_timestamp based on current timestamp, delay and duration variables.
    let start_timestamp = current_timestamp + delay
    let end_timestamp = start_timestamp + duration

    # Get the voting power of the proposer
    let (voting_power) = IVotingStrategy.get_voting_power(
        contract_address=voting_strategy_contract,
        timestamp=start_timestamp,
        address=proposer_address,
        params_len=params_len,
        params=params)

    # Verify that the proposer has enough voting power to trigger a proposal
    let (threshold) = proposal_threshold.read()
    let (is_lower) = uint256_lt(voting_power, threshold)
    if is_lower == 1:
        # Not enough voting power to create a proposal
        assert 1 = 0
    end

    # Create the proposal and its proposal id
    let proposal = Proposal(execution_hash, start_timestamp, end_timestamp, ethereum_block_number)
    let (proposal_id) = next_proposal_nonce.read()

    # Store the proposal
    proposal_registry.write(proposal_id, proposal)

    # Emit event
    proposal_created.emit(proposal_id, proposer_address, proposal, metadata_uri_len, metadata_uri)

    # Increase the proposal nonce
    next_proposal_nonce.write(proposal_id + 1)

    return ()
end

@view
func get_vote_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        voter_address : EthAddress, proposal_id : felt) -> (vote : Vote):
    return vote_registry.read(proposal_id, voter_address)
end

@view
func get_proposal_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
        proposal_id : felt) -> (proposal_info : ProposalInfo):
    let (proposal) = proposal_registry.read(proposal_id)

    let (_power_against) = vote_power.read(proposal_id, Choice.AGAINST)
    let (_power_for) = vote_power.read(proposal_id, Choice.FOR)
    let (_power_abstain) = vote_power.read(proposal_id, Choice.ABSTAIN)
    return (
        ProposalInfo(proposal=proposal, power_for=_power_for, power_against=_power_against, power_abstain=_power_abstain))
end
