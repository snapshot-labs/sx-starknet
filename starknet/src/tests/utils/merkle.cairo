use array::{ArrayTrait, SpanTrait};
use clone::Clone;
use traits::Into;
use result::ResultTrait;
use option::OptionTrait;
use hash::LegacyHash;
use sx::utils::merkle::{Leaf, Hash};
use starknet::contract_address_try_from_felt252;
use sx::types::UserAddress;

impl SpanIntoArray<T, impl TClone: Clone<T>, impl TDrop: Drop<T>> of Into<Span<T>, Array<T>> {
    fn into(self: Span<T>) -> Array<T> {
        let mut self = self;
        let mut output = ArrayTrait::<T>::new();
        loop {
            match self.pop_front() {
                Option::Some(val) => output.append(val.clone()),
                Option::None => {
                    break;
                }
            };
        };
        output
    }
}

// Generates the proof for the given `index` in the `merkle_data`.
fn generate_proof(mut merkle_data: Span<felt252>, mut index: usize) -> Array<felt252> {
    let mut proof = ArrayTrait::new();

    loop {
        if merkle_data.len() == 1 {
            break;
        }

        if merkle_data.len() % 2 != 0 {
            let mut cpy = merkle_data.into();
            cpy.append(0_felt252); // append 0 because of odd length
            merkle_data = cpy.span();
        }

        let next_level = get_next_level(merkle_data);

        let mut index_parent = 0_usize;
        let mut i = 0_usize;
        loop {
            if i == merkle_data.len() {
                break;
            }
            if i == index {
                index_parent = i / 2;
                if i % 2 == 0 {
                    proof.append(*merkle_data.at(index + 1));
                } else {
                    proof.append(*merkle_data.at(index - 1));
                }
            }
            i += 1;
        };
        merkle_data = next_level.span();
        index = index_parent;
    };
    proof
}

// Generates the merkle root from the 
fn generate_merkle_root(mut merkle_data: Span<felt252>) -> felt252 {
    if merkle_data.len() == 1 {
        return *merkle_data.pop_front().unwrap();
    }

    if merkle_data.len() % 2 != 0 {
        let mut cpy = merkle_data.into();
        cpy.append(0_felt252); // append 0 because of odd length
        merkle_data = cpy.span();
    }

    let next_level = get_next_level(merkle_data);
    generate_merkle_root(next_level.span())
}

fn get_next_level(mut merkle_data: Span<felt252>) -> Array<felt252> {
    let mut next_level = ArrayTrait::<felt252>::new();
    loop {
        match merkle_data.pop_front() {
            Option::Some(a) => {
                match merkle_data.pop_front() {
                    Option::Some(b) => {
                        // compare
                        let a_: u256 = (*a).into();
                        let b_: u256 = (*b).into();
                        if a_ > b_ {
                            let node = LegacyHash::hash(*a, *b);
                            next_level.append(node);
                        } else {
                            let node = LegacyHash::hash(*b, *a);
                            next_level.append(node);
                        }
                    },
                    Option::None => panic_with_felt252('Incorrect array length'),
                }
            },
            Option::None => {
                break;
            }
        };
    };
    next_level
}

// Generates the `merkle_data` from the members.
// The `merkle_data` corresponds to the hashes leaves of the members.
fn generate_merkle_data(members: Span<Leaf>) -> Array<felt252> {
    let mut members_ = members;
    let mut output = ArrayTrait::<felt252>::new();
    loop {
        match members_.pop_front() {
            Option::Some(leaf) => {
                output.append(leaf.hash());
            },
            Option::None => {
                break;
            },
        };
    };
    output
}

// Generates n members with voting power 1, 2, 3, and 
// address 1, 2, 3, ...
// Even members will be Ethereum addresses and odd members will be Starknet addresses.
fn generate_n_members(n: usize) -> Array<Leaf> {
    let mut members = ArrayTrait::<Leaf>::new();
    let mut i = 1_usize;
    loop {
        if i >= n + 1 {
            break;
        }
        let mut address = UserAddress::Custom(0);
        if i % 2 == 0 {
            address = UserAddress::Ethereum(starknet::EthAddress { address: i.into() });
        } else {
            address = UserAddress::Starknet(contract_address_try_from_felt252(i.into()).unwrap());
        }
        members.append(Leaf { address: address, voting_power: i.into() });
        i += 1;
    };
    members
}
