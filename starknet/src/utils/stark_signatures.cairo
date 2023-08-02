use starknet::{ContractAddress, contract_address_to_felt252, get_tx_info, get_contract_address};
use array::{ArrayTrait, SpanTrait};
use traits::Into;
use box::BoxTrait;
use clone::Clone;
use serde::Serde;
use ecdsa::check_ecdsa_signature;
use hash::LegacyHash;
use integer::u256_from_felt252;
use sx::utils::types::{Strategy, IndexedStrategy, Choice, Felt252ArrayIntoU256Array};
use sx::utils::math::pow;
use sx::utils::constants::{
    STARKNET_MESSAGE, DOMAIN_TYPEHASH, STRATEGY_TYPEHASH, INDEXED_STRATEGY_TYPEHASH, U256_TYPEHASH,
    PROPOSE_TYPEHASH, VOTE_TYPEHASH, UPDATE_PROPOSAL_TYPEHASH
};

impl LegacyHashSpanFelt252 of LegacyHash<Span<felt252>> {
    fn hash(state: felt252, mut value: Span<felt252>) -> felt252 {
        let mut call_data_state: felt252 = 0;
        loop {
            match value.pop_front() {
                Option::Some(item) => {
                    call_data_state = LegacyHash::hash(call_data_state, *item);
                },
                Option::None(_) => {
                    break call_data_state;
                },
            };
        }
    }
}

trait StructHash<T> {
    fn struct_hash(self: @T) -> felt252;
}

impl StructHashSpanFelt252 of StructHash<Span<felt252>> {
    fn struct_hash(self: @Span<felt252>) -> felt252 {
        let mut call_data_state = LegacyHash::hash(0, *self);
        call_data_state = LegacyHash::hash(call_data_state, (*self).len());
        call_data_state
    }
}

impl StructHashStrategy of StructHash<Strategy> {
    fn struct_hash(self: @Strategy) -> felt252 {
        let mut encoded_data = ArrayTrait::<felt252>::new();
        STRATEGY_TYPEHASH.serialize(ref encoded_data);
        (*self.address).serialize(ref encoded_data);
        self.params.span().struct_hash().serialize(ref encoded_data);
        encoded_data.span().struct_hash()
    }
}

impl StructHashIndexedStrategy of StructHash<IndexedStrategy> {
    fn struct_hash(self: @IndexedStrategy) -> felt252 {
        let mut encoded_data = ArrayTrait::<felt252>::new();
        INDEXED_STRATEGY_TYPEHASH.serialize(ref encoded_data);
        (*self.index).serialize(ref encoded_data);
        self.params.span().struct_hash().serialize(ref encoded_data);
        encoded_data.span().struct_hash()
    }
}

impl StructHashIndexedStrategySpan of StructHash<Span<IndexedStrategy>> {
    fn struct_hash(self: @Span<IndexedStrategy>) -> felt252 {
        let mut encoded_data = ArrayTrait::<felt252>::new();
        let mut i: usize = 0;
        loop {
            if i >= (*self).len() {
                break ();
            };
            encoded_data.append((*self).at(i).struct_hash());
            i += 1;
        };
        encoded_data.span().struct_hash()
    }
}

impl StructHashU256 of StructHash<u256> {
    fn struct_hash(self: @u256) -> felt252 {
        let mut encoded_data = ArrayTrait::<felt252>::new();
        U256_TYPEHASH.serialize(ref encoded_data);
        self.serialize(ref encoded_data);
        encoded_data.span().struct_hash()
    }
}

// Reverts if the signature was not signed by the author. 
fn verify_propose_sig(
    domain_hash: felt252,
    r: felt252,
    s: felt252,
    target: ContractAddress,
    author: ContractAddress,
    execution_strategy: Strategy,
    user_proposal_validation_params: Array<felt252>,
    salt: felt252,
    public_key: felt252
) {
    let digest: felt252 = get_propose_digest(
        domain_hash, target, author, execution_strategy, user_proposal_validation_params, salt
    );
    assert(check_ecdsa_signature(digest, public_key, r, s), 'Invalid signature');
}

fn verify_vote_sig(
    domain_hash: felt252,
    r: felt252,
    s: felt252,
    target: ContractAddress,
    voter: ContractAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Array<IndexedStrategy>,
    public_key: felt252
) {
    let digest: felt252 = get_vote_digest(
        domain_hash, target, voter, proposal_id, choice, user_voting_strategies
    );
    assert(check_ecdsa_signature(digest, public_key, r, s), 'Invalid signature');
}

fn verify_update_proposal_sig(
    domain_hash: felt252,
    r: felt252,
    s: felt252,
    target: ContractAddress,
    author: ContractAddress,
    proposal_id: u256,
    execution_strategy: Strategy,
    salt: felt252,
    public_key: felt252
) {
    let digest: felt252 = get_update_proposal_digest(
        domain_hash, target, author, proposal_id, execution_strategy, salt
    );
    assert(check_ecdsa_signature(digest, public_key, r, s), 'Invalid signature');
}

fn get_propose_digest(
    domain_hash: felt252,
    space: ContractAddress,
    author: ContractAddress,
    execution_strategy: Strategy,
    user_proposal_validation_params: Array<felt252>,
    salt: felt252
) -> felt252 {
    let mut encoded_data = ArrayTrait::<felt252>::new();
    PROPOSE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    user_proposal_validation_params.span().struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), author)
}

fn get_vote_digest(
    domain_hash: felt252,
    space: ContractAddress,
    voter: ContractAddress,
    proposal_id: u256,
    choice: Choice,
    user_voting_strategies: Array<IndexedStrategy>
) -> felt252 {
    let mut encoded_data = ArrayTrait::<felt252>::new();
    VOTE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    voter.serialize(ref encoded_data);
    proposal_id.struct_hash().serialize(ref encoded_data);
    choice.serialize(ref encoded_data);
    user_voting_strategies.span().struct_hash().serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), voter)
}

fn get_update_proposal_digest(
    domain_hash: felt252,
    space: ContractAddress,
    author: ContractAddress,
    proposal_id: u256,
    execution_strategy: Strategy,
    salt: felt252
) -> felt252 {
    let mut encoded_data = ArrayTrait::<felt252>::new();
    UPDATE_PROPOSAL_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    proposal_id.struct_hash().serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(domain_hash, encoded_data.span().struct_hash(), author)
}

fn get_domain_hash(name: felt252, version: felt252) -> felt252 {
    let mut encoded_data = ArrayTrait::<felt252>::new();
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
    let mut encoded_data = ArrayTrait::<felt252>::new();
    STARKNET_MESSAGE.serialize(ref encoded_data);
    domain_hash.serialize(ref encoded_data);
    signer.serialize(ref encoded_data);
    message_hash.serialize(ref encoded_data);
    encoded_data.span().struct_hash()
}
