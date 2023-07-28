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
        let mut encoded_data = ArrayTrait::<felt252>::new();
        STRATEGY_TYPEHASH.serialize(ref encoded_data);
        (*self.address).serialize(ref encoded_data);
        self.params.span().struct_hash().serialize(ref encoded_data);
        encoded_data.span().struct_hash()
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
    let mut encoded_data = ArrayTrait::<felt252>::new();
    PROPOSE_TYPEHASH.serialize(ref encoded_data);
    space.serialize(ref encoded_data);
    author.serialize(ref encoded_data);
    execution_strategy.struct_hash().serialize(ref encoded_data);
    user_proposal_validation_params.span().struct_hash().serialize(ref encoded_data);
    salt.serialize(ref encoded_data);
    hash_typed_data(encoded_data.span().struct_hash(), author)
}

fn hash_typed_data(message_hash: felt252, signer: ContractAddress) -> felt252 {
    let mut encoded_data = ArrayTrait::<felt252>::new();
    STARKNET_MESSAGE.serialize(ref encoded_data);
    DOMAIN_HASH.serialize(ref encoded_data);
    signer.serialize(ref encoded_data);
    message_hash.serialize(ref encoded_data);
    encoded_data.span().struct_hash()
}
