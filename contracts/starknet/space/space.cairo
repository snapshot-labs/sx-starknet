%lang starknet

from starkware.starknet.common.syscalls import ( get_caller_address, get_block_number )
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_le, assert_nn, assert_not_zero

struct Vote:
    member choice: felt # TODO use Choice enum
    member eth_address: felt # TODO: use address
    member voting_power: felt
end

struct Proposal:
    member execution_hash: felt # TODO: Use Hash type
    member start_block: felt
    member end_block: felt
end

# TODO: use L1Address instead of felt
@contract_interface
namespace IVotingStrategy:
    func get_voting_power(address: felt, at: felt) -> (voting_power: felt):
    end
end

@storage_var
func voting_delay() -> (delay : felt):
end


@storage_var
func voting_period() -> (period : felt):
end

@storage_var
func proposal_threshold() -> (threshold : felt):
end

# TODO: Should be Address not felt
@storage_var
func voting_strategy() -> (strategy_address : felt):
end

@storage_var
func authenticator() -> (authenticator_address : felt):
end

@storage_var
func next_proposal_nonce() -> (nonce : felt):
end

@storage_var
func proposals(proposal_id: felt) -> (proposal : Proposal):
end

@storage_var
func votes(proposal_id: felt) -> (vote : Vote):
end

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(_voting_delay: felt, _voting_period: felt, _proposal_threshold: felt, _voting_strategy: felt, _authenticator: felt):
    # Sanity checks
    assert_nn(_voting_delay)
    assert_nn(_voting_period)
    assert_nn(_proposal_threshold)
    assert_not_zero(_voting_strategy)
    assert_not_zero(_authenticator)

    # Initialize the storage variables
    voting_delay.write(_voting_delay)
    voting_period.write(_voting_period)
    proposal_threshold.write(_proposal_threshold)
    voting_strategy.write(_voting_strategy)
    authenticator.write(_authenticator)

    return ()
end

# TODO: should be address not felt, and choice should be of enum Choice not felt
@external
func vote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(eth_address: felt, proposal_id: felt, choice: felt) -> ():

    # Verify that the caller is the authenticator contract.
    let (caller_address) = get_caller_address()
    let (authenticator_address) = authenticator.read()
    assert caller_address = authenticator_address

    let (proposal) = proposals.read(proposal_id)
    let (current_block) = get_block_number()

    # Make sure proposal is not closed
    assert_lt(current_block, proposal.end_block)

    # Make sure proposal has started
    assert_le(proposal.start_block, current_block)

    let (strategy_contract) = voting_strategy.read()

    # TODO: pass in `params_len` and `params`
    let (voting_power) = IVotingStrategy.get_voting_power(contract_address=strategy_contract, address=eth_address, at=current_block)

    let vote = Vote(choice, eth_address, voting_power)
    votes.write(proposal_id, vote)

    return ()
end

# Throws if the caller address is not identical to the authenticator address (stored in the `authenticator` variable)
func authenticator_only{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():
    let (caller_address) = get_caller_address()
    let (authenticator_address) = authenticator.read()

    # Ensure it has been initialized
    assert_not_zero(authenticator_address)
    # Ensure the caller is the authenticator contract
    assert caller_address = authenticator_address

    return ()
end

# Todo: use proper types
@external
func propose{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(eth_address: felt, execution_hash: felt, metadata_uri: felt) -> ():
    # Verify that the caller is the authenticator contract.
    authenticator_only()

    let (current_block) = get_block_number()
    let (delay) = voting_delay.read()
    let (duration) = voting_period.read()

    # Define start_block and end_block based on current block, delay and duration variables.
    let start_block = current_block + delay
    let end_block = start_block + duration

    let proposal = Proposal(execution_hash, start_block, end_block)
    let (proposal_id) = next_proposal_nonce.read()

    # Store the proposal
    proposals.write(proposal_id, proposal)

    # Increase the proposal nonce
    next_proposal_nonce.write(proposal_id + 1)

    return ()
end
