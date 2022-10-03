%lang starknet

from openzeppelin.account.library import AccountCallArray
from contracts.starknet.lib.general_address import Address
from contracts.starknet.lib.proposal_info import ProposalInfo
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace ISpaceaccount {
    func getPublicKey() -> (publicKey: felt) {
    }

    func supportsInterface(interfaceId: felt) -> (success: felt) {
    }

    func setPublicKey(newPublicKey: felt) {
    }

    func isValidSignature(hash: felt, signature_len: felt, signature: felt*) -> (isValid: felt) {
    }

    func __validate__(
        call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*
    ) {
    }

    func __validate_declare__(hash: felt) {
    }

    func __execute__(
        call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*
    ) -> (response_len: felt, response: felt*) {
    }

    func propose(
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
    }

    func vote(
        voter_address: Address,
        proposal_id: felt,
        choice: felt,
        used_voting_strategies_len: felt,
        used_voting_strategies: felt*,
        user_voting_strategy_params_flat_len: felt,
        user_voting_strategy_params_flat: felt*,
    ) -> () {
    }

    func finalize_proposal(proposal_id: felt, execution_params_len: felt, execution_params: felt*) {
    }

    func cancel_proposal(proposal_id: felt, execution_params_len: felt, execution_params: felt*) {
    }

    func has_voted(proposal_id: felt, voter_address: Address) -> (voted: felt) {
    }

    func get_proposal_info(proposal_id: felt) -> (proposal_info: ProposalInfo) {
    }

    func update_controller(new_controller: felt) {
    }

    func update_quorum(new_quorum: Uint256) {
    }

    func update_voting_delay(new_delay: felt) {
    }

    func update_min_voting_duration(new_min_voting_duration: felt) {
    }

    func update_max_voting_duration(new_max_voting_duration: felt) {
    }

    func update_proposal_threshold(new_proposal_threshold: Uint256) {
    }

    func update_metadata_uri(new_metadata_uri_len: felt, new_metadata_uri: felt*) {
    }

    func add_execution_strategies(addresses_len: felt, addresses: felt*) {
    }

    func remove_execution_strategies(addresses_len: felt, addresses: felt*) {
    }

    func add_voting_strategies(
        addresses_len: felt, addresses: felt*, params_flat_len: felt, params_flat: felt*
    ) {
    }

    func remove_voting_strategies(indexes_len: felt, indexes: felt*) {
    }

    func add_authenticators(addresses_len: felt, addresses: felt*) {
    }

    func remove_authenticators(addresses_len: felt, addresses: felt*) {
    }
}
