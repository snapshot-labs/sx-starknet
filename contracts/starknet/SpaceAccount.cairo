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
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    public_key: felt,
    voting_delay: felt,
    min_voting_duration: felt,
    max_voting_duration: felt,
    proposal_threshold: felt,
    controller: felt,
    quorum: felt,
    voting_strategy_params_flat_len: felt,
    voting_strategy_params_flat: felt*,
    voting_strategies_len: felt,
    voting_strategies: felt*,
    authenticators_len: felt,
    authenticators: felt*,
    executors_len: felt,
    executors: felt*,
) {
    Account.initializer(public_key);

    Voting.initializer(
        voting_delay,
        min_voting_duration,
        max_voting_duration,
        proposal_threshold,
        controller,
        quorum,
        voting_strategy_params_flat_len,
        voting_strategy_params_flat,
        voting_strategies_len,
        voting_strategies,
        authenticators_len,
        authenticators,
        executors_len,
        executors,
    );
    return ();
}

//
// Getters
//

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

//
// Setters
//

@external
func setPublicKey{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newPublicKey: felt
) {
    Account.set_public_key(newPublicKey);
    return ();
}

//
// Business logic
//

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

// Finalizes the proposal, counts the voting power, and send the corresponding result to the L1 executor contract
@external
func finalize_proposal{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
}(proposal_id: felt, execution_params_len: felt, execution_params: felt*) {
    Voting.finalize_proposal(proposal_id, execution_params_len, execution_params);
    return ();
}

// Cancels the proposal. Only callable by the controller.
@external
func cancel_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    proposal_id: felt, execution_params_len: felt, execution_params: felt*
) {
    Voting.cancel_proposal(proposal_id, execution_params_len, execution_params);
    return ();
}

//
// View functions
//

@view
func get_vote_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    voter_address: Address, proposal_id: felt
) -> (vote: Vote) {
    return Voting.get_vote_info(voter_address, proposal_id);
}

@view
func get_proposal_info{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    proposal_id: felt
) -> (proposal_info: ProposalInfo) {
    return Voting.get_proposal_info(proposal_id);
}

//
// Setters
//

@external
func update_controller{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_controller: felt
) {
    Voting.update_controller(new_controller);
    return ();
}

@external
func update_quorum{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_quorum: felt
) {
    Voting.update_quorum(new_quorum);
    return ();
}

@external
func update_voting_delay{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    new_delay: felt
) {
    Voting.update_voting_delay(new_delay);
    return ();
}

@external
func update_min_voting_duration{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(new_min_voting_duration: felt) {
    Voting.update_min_voting_duration(new_min_voting_duration);
    return ();
}

@external
func update_max_voting_duration{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(new_max_voting_duration: felt) {
    Voting.update_max_voting_duration(new_max_voting_duration);
    return ();
}

@external
func update_proposal_threshold{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(new_proposal_threshold: felt) {
    Voting.update_proposal_threshold(new_proposal_threshold);
    return ();
}

@external
func add_execution_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(addresses_len: felt, addresses: felt*) {
    Voting.add_execution_strategies(addresses_len, addresses);
    return ();
}

@external
func remove_execution_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(addresses_len: felt, addresses: felt*) {
    Voting.remove_execution_strategies(addresses_len, addresses);
    return ();
}

@external
func add_voting_strategies{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*, params_flat_len: felt, params_flat: felt*
) {
    Voting.add_voting_strategies(addresses_len, addresses, params_flat_len, params_flat);
    return ();
}

@external
func remove_voting_strategies{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt
}(indexes_len: felt, indexes: felt*) {
    Voting.remove_voting_strategies(indexes_len, indexes);
    return ();
}

@external
func add_authenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*
) {
    Voting.add_authenticators(addresses_len, addresses);
    return ();
}

@external
func remove_authenticators{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    addresses_len: felt, addresses: felt*
) {
    Voting.remove_authenticators(addresses_len, addresses);
    return ();
}
