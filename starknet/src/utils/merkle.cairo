use core::traits::Into;
use array::{ArrayTrait, Span, SpanTrait};
use option::OptionTrait;
use serde::Serde;
use starknet::ContractAddress;
use clone::Clone;
use hash::{LegacyHash};
use debug::PrintTrait;

#[derive(Copy, Clone, Drop, Serde)]
struct Leaf {
    address: ContractAddress, // use UserAddress
    voting_power: u256,
}

trait Hash<T> {
    fn hash(self: @T) -> felt252;
}

impl LegacyHashSpan of LegacyHash<Span<felt252>> {
    fn hash(mut state: felt252, mut value: Span<felt252>) -> felt252 {
        let len = value.len();
        loop {
            match value.pop_front() {
                Option::Some(current) => {
                    state = LegacyHash::hash(state, *current);
                },
                Option::None => {
                    break;
                },
            };
        };
        LegacyHash::hash(state, len) // append the length to conform to computeHashOnElements
    }
}

impl HashType<T, impl TSerde: Serde<T>> of Hash<T> {
    fn hash(self: @T) -> felt252 {
        let mut serialized = ArrayTrait::new();
        Serde::<T>::serialize(self, ref serialized);
        let hashed = LegacyHash::hash(0, serialized.span());
        hashed
    }
}

fn assert_valid_proof(root: felt252, leaf: Leaf, proof: Span<felt252>) {
    let leaf_node = leaf.hash();
    let computed_root = _compute_merkle_root(leaf_node, proof);
    assert(computed_root == root, 'Merkle: Invalid proof');
}

fn _compute_merkle_root(mut current: felt252, proof: Span<felt252>) -> felt252 {
    let mut proof = proof;
    loop {
        match proof.pop_front() {
            Option::Some(val) => {
                let p_u256: u256 = (*val).into(); // Needed for type annotation
                if current.into() >= p_u256 {
                    current = LegacyHash::hash(current, *val);
                } else {
                    current = LegacyHash::hash(*val, current);
                };
            },
            Option::None => {
                break current;
            },
        };
    }
}
