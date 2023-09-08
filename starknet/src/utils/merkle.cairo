use hash::{LegacyHash};
use sx::{types::UserAddress, utils::legacy_hash::LegacyHashSpanFelt252};

/// Leaf struct for the merkle tree
#[derive(Copy, Clone, Drop, Serde)]
struct Leaf {
    address: UserAddress,
    voting_power: u256,
}

/// Hash wrapper.
trait Hash<T> {
    fn hash(self: @T) -> felt252;
}

impl HashSerde<T, impl TSerde: Serde<T>> of Hash<T> {
    fn hash(self: @T) -> felt252 {
        let mut serialized = array![];
        Serde::<T>::serialize(self, ref serialized);
        let hashed = LegacyHash::hash(0, serialized.span());
        hashed
    }
}

/// Asserts that the given proof is valid for the given leaf and root.
fn assert_valid_proof(root: felt252, leaf: Leaf, proof: Span<felt252>) {
    let leaf_node = leaf.hash();
    let computed_root = _compute_merkle_root(leaf_node, proof);
    assert(computed_root == root, 'Merkle: Invalid proof');
}

/// Internal helper function that computes the merkle root, given a leaf node and a proof.
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
