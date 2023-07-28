use starknet::{ContractAddress, contract_address_to_felt252};
use array::{ArrayTrait, SpanTrait};
use traits::Into;
use clone::Clone;
use serde::Serde;
use starknet::secp256k1;
use hash::LegacyHash;
use integer::u256_from_felt252;
use sx::utils::types::{Strategy, IndexedStrategy, Choice, Felt252ArrayIntoU256Array};
use sx::utils::math::pow;
use sx::utils::constants::{STARKNET_MESSAGE, DOMAIN_HASH, STRATEGY_TYPEHASH, PROPOSE_TYPEHASH};

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
        let mut call_data_state = LegacyHash::hash(0, STRATEGY_TYPEHASH);
        call_data_state = LegacyHash::<felt252>::hash(call_data_state, (*self.address).into());
        call_data_state = LegacyHash::hash(call_data_state, self.params.span().struct_hash());
        call_data_state
    }
}

impl LegacyHashStrategy of LegacyHash<Strategy> {
    fn hash(state: felt252, value: Strategy) -> felt252 {
        let state = LegacyHash::<felt252>::hash(state, value.address.into());
        LegacyHash::hash(state, value.params.span())
    }
}

// Reverts if the signature was not signed by the author. 
fn verify_propose_sig(
    r: felt252,
    s: felt252,
    target: ContractAddress,
    author: ContractAddress,
    execution_strategy: Strategy,
    user_proposal_validation_params: Array<felt252>,
    salt: felt252,
) {
    let digest: felt252 = get_propose_digest(
        target, author, execution_strategy, user_proposal_validation_params, salt
    );
// TODO: Actually verify the signature when it gets added
// secp256k1::verify_eth_signature(digest, r, s, v, author);
}

fn get_propose_digest(
    space: ContractAddress,
    author: ContractAddress,
    execution_strategy: Strategy,
    user_proposal_validation_params: Array<felt252>,
    salt: felt252
) -> felt252 {
    // let mut encoded_data = ArrayTrait::<felt252>::new();
    // PROPOSE_TYPEHASH.serialize(ref encoded_data);
    // space.serialize(ref encoded_data);
    // author.serialize(ref encoded_data);
    // // TODO: proper typehashes for below
    // LegacyHash::hash(0, execution_strategy).serialize(ref encoded_data);
    // LegacyHash::hash(0, user_proposal_validation_params.span()).serialize(ref encoded_data);
    // salt.serialize(ref encoded_data);
    // let message_hash = LegacyHash::hash(0, encoded_data.span());
    // hash_typed_data(message_hash)

    // let mut encoded_data = ArrayTrait::<felt252>::new();
    // STRATEGY_TYPEHASH.serialize(ref encoded_data);
    // execution_strategy.serialize(ref encoded_data);
    // LegacyHash::hash(0, encoded_data.span())
    execution_strategy.params.span().struct_hash()
}

fn hash_typed_data(message_hash: felt252) -> felt252 {
    let mut encoded_data = ArrayTrait::<felt252>::new();
    STARKNET_MESSAGE.serialize(ref encoded_data);
    DOMAIN_HASH.serialize(ref encoded_data);
    message_hash.serialize(ref encoded_data);
    LegacyHash::hash(0, encoded_data.span())
}
