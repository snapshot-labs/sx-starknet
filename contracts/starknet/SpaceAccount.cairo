// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_tx_info
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.account.library import Account, AccountCallArray
from contracts.starknet.lib.voting import Voting

from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.proposal_info import ProposalInfo
from contracts.starknet.lib.vote import Vote

//
// @title Snapshot X Space Account
// @author SnapshotLabs
// @notice Core contract for Snapshot X, each DAO should deploy their own instance
//

// @dev Constructor
// @param public_key The public key that can execute transactions via this account - Can set to zero if this functionality is unwanted
// @param voting_delay The delay between when a proposal is created, and when the voting starts
// @param min_voting_duration The minimum duration of the voting period
// @param max_voting_duration The maximum duration of the voting period
// @param proposal_threshold The minimum amount of voting power needed to be able to create a new proposal in the space
// @param controller The address of the controller account for the space
// @param quorum The minimum total voting power required for a proposal to pass
// @param voting_strategies Array of whitelisted voting strategy contract addresses
// @param voting_strategy_params_flat Flattened 2D array of voting strategy parameters
// @param authenticators Array of whitelisted authenticator contract addresses
// @param execution_strategies Array of whitelisted execution strategy contract addresses
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    public_key: felt,
    voting_delay: felt,
    min_voting_duration: felt,
    max_voting_duration: felt,
    proposal_threshold: Uint256,
    controller: felt,
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
    Account.initializer(public_key);

    Voting.initializer(
        voting_delay,
        min_voting_duration,
        max_voting_duration,
        proposal_threshold,
        controller,
        quorum,
        voting_strategies_len,
        voting_strategies,
        voting_strategy_params_flat_len,
        voting_strategy_params_flat,
        authenticators_len,
        authenticators,
        execution_strategies_len,
        execution_strategies,
    );
    return ();
}

// ----- OZ Account Functionality -----

@view
func getPublicKey{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    publicKey: felt
) {
    let (publicKey: felt) = Account.get_public_key();
    return (publicKey=publicKey);
}

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return Account.supports_interface(interfaceId);
}

@external
func setPublicKey{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newPublicKey: felt
) {
    Account.set_public_key(newPublicKey);
    return ();
}

@view
func isValidSignature{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(hash: felt, signature_len: felt, signature: felt*) -> (isValid: felt) {
    let (isValid: felt) = Account.is_valid_signature(hash, signature_len, signature);
    return (isValid=isValid);
}

@external
func __validate__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) {
    let (tx_info) = get_tx_info();
    Account.is_valid_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}

@external
func __validate_declare__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(class_hash: felt) {
    let (tx_info) = get_tx_info();
    Account.is_valid_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}

@external
func __execute__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) -> (
    response_len: felt, response: felt*
) {
    let (response_len, response) = Account.execute(
        call_array_len, call_array, calldata_len, calldata
    );
    return (response_len, response);
}

// ----- Space Contract Functionality -----

// @dev Creates a proposal
// @param proposer_address The address of the proposal creator
// @param metadata_uri_string_len The string length of the metadata URI (required for keccak hashing)
// @param metadata_uri The metadata URI for the proposal
// @param used_voting_strategies The voting strategies (within the whitelist for the space) that the proposal creator has non-zero voting power with
// @param user_voting_strategy_params_flat Flattened 2D array of parameters for the voting strategies used
// @param execution_params Execution parameters for the proposal
@external
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
    Voting.propose(
        proposer_address,
        metadata_uri_string_len,
        metadata_uri_len,
        metadata_uri,
        executor,
        used_voting_strategies_len,
        used_voting_strategies,
        user_voting_strategy_params_flat_len,
        user_voting_strategy_params_flat,
        execution_params_len,
        execution_params,
    );
    return ();
}

// @dev Casts a vote on a proposal
// @param voter_address The address of the voter
// @param proposal_id The ID of the proposal in the space
// @param choice The voter's choice (FOR, AGAINST, ABSTAIN)
// @used_voting_strategies The voting strategies (within the whitelist for the space) that the voter has non-zero voting power with
// @user_voting_strategy_params_flat Flattened 2D array of parameters for the voting strategies used
@external
func vote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    voter_address: Address,
    proposal_id: felt,
    choice: felt,
    used_voting_strategies_len: felt,
    used_voting_strategies: felt*,
    user_voting_strategy_params_flat_len: felt,
    user_voting_strategy_params_flat: felt*,
) -> () {
    Voting.vote(
        voter_address,
        proposal_id,
        choice,
        used_voting_strategies_len,
        used_voting_strategies,
        user_voting_strategy_params_flat_len,
        user_voting_strategy_params_flat,
    );
    return ();
}

// @dev Finalizes a proposal, triggering execution via the chosen execution strategy
// @param proposal_id The ID of the proposal
// @param execution_params Execution parameters for the proposal (must be the same as those submitted during proposal creation)
@external
func finalizeProposal{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
}(proposal_id: felt, execution_params_len: felt, execution_params: felt*) {
    Voting.finalize_proposal(proposal_id, execution_params_len, execution_params);
    return ();
}

// @dev Cancels a proposal. Only callable by the controller.
// @param proposal_id The ID of the proposal
// @param execution_params Execution parameters for the proposal (must be the same as those submitted during proposal creation)
@external
func cancelProposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    proposal_id: felt, execution_params_len: felt, execution_params: felt*
) {
    Voting.cancel_proposal(proposal_id, execution_params_len, execution_params);
    return ();
}

// @dev Checks to see whether a given address has voted in a proposal
// @param proposal_id The proposal ID
// @param voter_address The voter's address
// @return voted 1 if user has voted, otherwise 0
@view
func hasVoted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    proposal_id: felt, voter_address: Address
) -> (voted: felt) {
    return Voting.has_voted(proposal_id, voter_address);
}

// @dev Returns proposal information
// @param proposal_id The proposal ID
// @return proposal_info Struct containing proposal information
@view
func getProposalInfo{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    proposal_id: felt
) -> (proposal_info: ProposalInfo) {
    return Voting.get_proposal_info(proposal_id);
}

// @dev Updates the controller
// @param new_controller The new controller account address
@external
func setController{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_controller: felt
) {
    Voting.update_controller(new_controller);
    return ();
}

// @dev Updates the quorum
// @param new_quorum The new quorum
@external
func setQuorum{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_quorum: Uint256
) {
    Voting.update_quorum(new_quorum);
    return ();
}

// @dev Updates the voting delay
// @param new_voting_delay The new voting delay
@external
func setVotingDelay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_delay: felt
) {
    Voting.update_voting_delay(new_delay);
    return ();
}

// @dev Updates the minimum voting duration
// @param new_min_voting_duration The new minimum voting duration
@external
func setMinVotingDuration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_min_voting_duration: felt
) {
    Voting.update_min_voting_duration(new_min_voting_duration);
    return ();
}

// @dev Updates the maximum voting duration
// @param new_max_voting_duration The new maximum voting duration
@external
func setMaxVotingDuration{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_max_voting_duration: felt
) {
    Voting.update_max_voting_duration(new_max_voting_duration);
    return ();
}

// @dev Updates the proposal threshold
// @param new_proposal_threshold The new proposal threshold
@external
func setProposalThreshold{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_proposal_threshold: Uint256
) {
    Voting.update_proposal_threshold(new_proposal_threshold);
    return ();
}

// @dev Updates the metadata URI
// @param new_metadata_uri The new metadata URI
@external
func setMetadataUri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_metadata_uri_len: felt, new_metadata_uri: felt*
) {
    Voting.update_metadata_uri(new_metadata_uri_len, new_metadata_uri);
    return ();
}

// @dev Adds execution strategy contracts to the whitelist
// @param addresses Array of execution strategy contract addresses
@external
func addExecutionStrategies{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*
) {
    Voting.add_execution_strategies(addresses_len, addresses);
    return ();
}

// @dev Removes execution strategy contracts from the whitelist
// @param addresses Array of execution strategy contract addresses
@external
func removeExecutionStrategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(addresses_len: felt, addresses: felt*) {
    Voting.remove_execution_strategies(addresses_len, addresses);
    return ();
}

// @dev Adds voting strategy contracts to the whitelist
// @param addresses Array of voting strategy contract addresses
// @param params_flat Flattened 2D array of voting strategy parameters
@external
func addVotingStrategies{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*, params_flat_len: felt, params_flat: felt*
) {
    Voting.add_voting_strategies(addresses_len, addresses, params_flat_len, params_flat);
    return ();
}

// @dev Removes voting strategy contracts from the whitelist
// @param indexes Array of voting strategy indexes to remove
@external
func removeVotingStrategies{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    indexes_len: felt, indexes: felt*
) {
    Voting.remove_voting_strategies(indexes_len, indexes);
    return ();
}

// @dev Adds authenticator contracts to the whitelist
// @param addresses Array of authenticator contract addresses
@external
func addAuthenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*
) {
    Voting.add_authenticators(addresses_len, addresses);
    return ();
}

// @dev Removes authenticator contracts from the whitelist
// @param addresses Array of authenticator contract addresses
@external
func removeAuthenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*
) {
    Voting.remove_authenticators(addresses_len, addresses);
    return ();
}
