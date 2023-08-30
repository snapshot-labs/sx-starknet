use core::starknet::SyscallResultTrait;
use starknet::{ContractAddress, get_tx_info, get_contract_address};
use array::{ArrayTrait, SpanTrait};
use traits::Into;
use box::BoxTrait;
use serde::Serde;
use sx::{
    types::{Strategy, IndexedStrategy, Choice},
    utils::{
        struct_hash::StructHash,
        constants::{
            STARKNET_MESSAGE, DOMAIN_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH,
            UPDATE_PROPOSAL_TYPEHASH, ERC165_ACCOUNT_INTERFACE_ID, ERC165_OLD_ACCOUNT_INTERFACE_ID
        }
    },
    interfaces::{
        AccountABIDispatcher, AccountABIDispatcherTrait, AccountCamelABIDispatcher,
        AccountCamelABIDispatcherTrait
    }
};

fn verify_propose_sig(
    domain_hash: felt252,
    signature: Array<felt252>,
    target: ContractAddress,
    author: ContractAddress,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    metadata_URI: Span<felt252>,
    salt: felt252,
    account_type: felt252,
) {
    let digest: felt252 = get_propose_digest(
        domain_hash,
        target,
        author,
        execution_strategy,
        user_proposal_validation_params,
        metadata_URI,
        salt
    );

    verify_signature(digest, signature, author, account_type);
}

fn verify_vote_sig(
    domain_hash: felt252,
    signature: Array<felt252>,
    target: ContractAddress,
    voter: ContractAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>,
    metadata_URI: Span<felt252>,
    account_type: felt252,
) {
    let digest: felt252 = get_vote_digest(
        domain_hash, target, voter, proposal_id, choice, user_voting_strategies, metadata_URI
    );
    verify_signature(digest, signature, voter, account_type);
}

fn verify_update_proposal_sig(
    domain_hash: felt252,
    signature: Array<felt252>,
    target: ContractAddress,
    author: ContractAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    metadata_URI: Span<felt252>,
    salt: felt252,
    account_type: felt252,
) {
    let digest: felt252 = get_update_proposal_digest(
        domain_hash, target, author, proposal_id, execution_strategy, metadata_URI, salt
    );
    verify_signature(digest, signature, author, account_type);
}

fn get_propose_digest(
    domain_hash: felt252,
    space: ContractAddress,
    author: ContractAddress,
    execution_strategy: @Strategy,
    user_proposal_validation_params: Span<felt252>,
    metadata_URI: Span<felt252>,
    salt: felt252
) -> felt252 {
    let mut encoded_data = array![];
    PROPOSE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    user_proposal_validation_params.struct_hash().serialize(ref encoded_data);
    metadata_URI.struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), author)
}

fn get_vote_digest(
    domain_hash: felt252,
    space: ContractAddress,
    voter: ContractAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Span<IndexedStrategy>,
    metadata_URI: Span<felt252>,
) -> felt252 {
    let mut encoded_data = array![];
    VOTE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    voter.serialize(ref encoded_data);
    proposal_id.struct_hash().serialize(ref encoded_data);
    choice.serialize(ref encoded_data);
    user_voting_strategies.struct_hash().serialize(ref encoded_data);
    metadata_URI.struct_hash().serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), voter)
}

fn get_update_proposal_digest(
    domain_hash: felt252,
    space: ContractAddress,
    author: ContractAddress,
    proposal_id: u256,
    execution_strategy: @Strategy,
    metadata_URI: Span<felt252>,
    salt: felt252
) -> felt252 {
    let mut encoded_data = array![];
    UPDATE_PROPOSAL_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    proposal_id.struct_hash().serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    metadata_URI.struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), author)
}

fn get_domain_hash(name: felt252, version: felt252) -> felt252 {
    let mut encoded_data = array![];
    DOMAIN_TYPEHASH.serialize(ref encoded_data);
    name.serialize(ref encoded_data);
    version.serialize(ref encoded_data);
    get_tx_info().unbox().chain_id.serialize(ref encoded_data);
    get_contract_address().serialize(ref encoded_data);
    encoded_data.span().struct_hash()
}

fn hash_typed_data(
    domain_hash: felt252, message_hash: felt252, signer: ContractAddress
) -> felt252 {
    let mut encoded_data = array![];
    STARKNET_MESSAGE.serialize(ref encoded_data);
    domain_hash.serialize(ref encoded_data);
    signer.serialize(ref encoded_data);
    message_hash.serialize(ref encoded_data);
    encoded_data.span().struct_hash()
}

/// Verifies the signature of a message by calling the account contract.
fn verify_signature(
    digest: felt252, signature: Array<felt252>, account: ContractAddress, account_type: felt252
) {
    if account_type == 'snake' {
        assert(
            AccountCamelABIDispatcher { contract_address: account }
                .supportsInterface(ERC165_ACCOUNT_INTERFACE_ID) == true,
            'Invalid Account'
        );
        AccountCamelABIDispatcher { contract_address: account }.isValidSignature(digest, signature);
    } else if account_type == 'camel' {
        assert(
            AccountABIDispatcher { contract_address: account }
                .supports_interface(ERC165_OLD_ACCOUNT_INTERFACE_ID) == true,
            'Invalid Account'
        );
        AccountABIDispatcher { contract_address: account }.is_valid_signature(digest, signature);
    } else {
        panic_with_felt252('Invalid Account Type');
    }
}
