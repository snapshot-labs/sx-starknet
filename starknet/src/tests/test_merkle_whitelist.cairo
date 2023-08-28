#[cfg(test)]
mod merkle_utils {
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
            let mut output = array![];
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
        let mut proof = array![];

        loop {
            if merkle_data.len() == 1 {
                break;
            }

            if merkle_data.len() % 2 != 0 {
                let mut cpy: Array<felt252> = merkle_data.into();
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
            let mut cpy: Array<felt252> = merkle_data.into();
            cpy.append(0_felt252); // append 0 because of odd length
            merkle_data = cpy.span();
        }

        let next_level = get_next_level(merkle_data);
        generate_merkle_root(next_level.span())
    }

    fn get_next_level(mut merkle_data: Span<felt252>) -> Array<felt252> {
        let mut next_level = array![];
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
        let mut output = array![];
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
        let mut members = array![];
        let mut i = 1_usize;
        loop {
            if i >= n + 1 {
                break;
            }
            let mut address = UserAddress::Custom(0);
            if i % 2 == 0 {
                address = UserAddress::Ethereum(starknet::EthAddress { address: i.into() });
            } else {
                address =
                    UserAddress::Starknet(contract_address_try_from_felt252(i.into()).unwrap());
            }
            members.append(Leaf { address: address, voting_power: i.into() });
            i += 1;
        };
        members
    }
}

#[cfg(test)]
mod assert_valid_proof {
    use sx::tests::setup::setup::setup::{setup, deploy};
    use array::{ArrayTrait, SpanTrait};
    use option::OptionTrait;
    use sx::utils::merkle::{Leaf, assert_valid_proof, Hash};
    use starknet::{contract_address_const, contract_address_try_from_felt252};
    use clone::Clone;
    use traits::Into;
    use hash::LegacyHash;
    use serde::Serde;
    use super::merkle_utils::{
        generate_n_members, generate_merkle_data, generate_merkle_root, generate_proof
    };
    use sx::types::UserAddress;

    // Generates the proof and verifies the proof for every member in `members`.
    fn verify_all_members(members: Span<Leaf>) {
        let merkle_data = generate_merkle_data(members);
        let root = generate_merkle_root(merkle_data.span());
        let mut index = 0;
        loop {
            let proof = generate_proof(merkle_data.span(), index);
            if index == members.len() {
                break;
            }
            assert_valid_proof(root, *members.at(index), proof.span());
            index += 1;
        }
    }

    // Replaces the first element of `arr` with `value`.
    fn replace_first_element<T, impl TDrop: Drop<T>, impl TCopy: Copy<T>>(
        mut arr: Span<T>, value: T
    ) -> Array<T> {
        let mut output = ArrayTrait::new();
        output.append(value);

        arr.pop_front(); // remove first element
        loop {
            match arr.pop_front() {
                Option::Some(v) => output.append(*v),
                Option::None => {
                    break;
                },
            };
        };
        output
    }

    #[test]
    #[available_gas(10000000)]
    fn one_member() {
        let mut members = generate_n_members(1);
        verify_all_members(members.span());
    }

    #[test]
    #[available_gas(10000000)]
    fn two_members() {
        let members = generate_n_members(2);
        verify_all_members(members.span());
    }

    #[test]
    #[available_gas(10000000)]
    fn three_members() {
        let members = generate_n_members(3);
        verify_all_members(members.span());
    }

    #[test]
    #[available_gas(10000000)]
    fn four_members() {
        let members = generate_n_members(4);
        verify_all_members(members.span());
    }

    #[test]
    #[available_gas(1000000000)]
    fn one_hundred_members() {
        let members = generate_n_members(100);
        verify_all_members(members.span());
    }

    #[test]
    #[available_gas(1000000000)]
    fn one_hundred_and_one_members() {
        let members = generate_n_members(101);
        verify_all_members(members.span());
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', ))]
    fn no_leaf() {
        let root = 0;
        let leaf = Leaf {
            address: UserAddress::Starknet(contract_address_const::<0>()), voting_power: 0
        };
        let proof = array![];
        assert_valid_proof(root, leaf, proof.span());
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', ))]
    fn invalid_extra_node() {
        let mut members = array![
            Leaf {
                address: UserAddress::Starknet(contract_address_const::<5>()), voting_power: 5
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<4>()), voting_power: 4
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<3>()), voting_power: 3
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<2>()), voting_power: 2
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<1>()), voting_power: 1
            },
        ];
        let merkle_data = generate_merkle_data(members.span());

        let root = generate_merkle_root(merkle_data.span());
        let index = 2;
        let mut proof = generate_proof(merkle_data.span(), index);
        proof.append(0x1337); // Adding a useless node
        assert_valid_proof(root, *members.at(index), proof.span());
    }


    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', ))]
    fn invalid_proof() {
        let mut members = array![
            Leaf {
                address: UserAddress::Starknet(contract_address_const::<5>()), voting_power: 5
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<4>()), voting_power: 4
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<3>()), voting_power: 3
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<2>()), voting_power: 2
                }, Leaf {
                address: UserAddress::Starknet(contract_address_const::<1>()), voting_power: 1
            },
        ];
        let merkle_data = generate_merkle_data(members.span());

        let root = generate_merkle_root(merkle_data.span());
        let index = 2;
        let proof = generate_proof(merkle_data.span(), index);
        let fake_proof = replace_first_element(proof.span(), 0x1337);

        assert_valid_proof(root, *members.at(index), fake_proof.span());
    }
}

#[cfg(test)]
mod merkle_whitelist_voting_power {
    use array::ArrayTrait;
    use sx::utils::merkle::Leaf;
    use super::merkle_utils::{
        generate_merkle_root, generate_n_members, generate_merkle_data, generate_proof
    };
    use sx::voting_strategies::merkle_whitelist::{MerkleWhitelistVotingStrategy};
    use sx::interfaces::IVotingStrategy;
    use starknet::syscalls::deploy_syscall;
    use starknet::SyscallResult;
    use result::ResultTrait;
    use option::OptionTrait;
    use traits::TryInto;
    use sx::interfaces::{IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait};
    use serde::Serde;
    use starknet::contract_address_const;
    use sx::types::UserAddress;

    #[test]
    #[available_gas(1000000000)]
    fn one_hundred_members() {
        let members = generate_n_members(20);

        let (contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false,
        )
            .unwrap();
        let voting_strategy = IVotingStrategyDispatcher { contract_address: contract };
        let timestamp = 0x1234;
        let index = 2;
        let leaf = *members.at(index);
        let voter = leaf.address;

        let merkle_data = generate_merkle_data(members.span());
        let root = generate_merkle_root(merkle_data.span());
        let proof = generate_proof(merkle_data.span(), index);

        let mut params = array![];
        root.serialize(ref params);

        let mut user_params = array![];
        leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        voting_strategy.get_voting_power(timestamp, voter, params.span(), user_params.span());
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', 'ENTRYPOINT_FAILED'))]
    fn lying_voting_power() {
        let members = generate_n_members(20);

        let (contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false,
        )
            .unwrap();
        let voting_strategy = IVotingStrategyDispatcher { contract_address: contract };
        let timestamp = 0x1234;
        let index = 2;
        let leaf = *members.at(index);
        let voter = leaf.address;

        let merkle_data = generate_merkle_data(members.span());
        let root = generate_merkle_root(merkle_data.span());
        let proof = generate_proof(merkle_data.span(), index);

        let mut params = array![];
        root.serialize(ref params);

        let mut user_params = array![];
        let fake_leaf = Leaf {
            address: leaf.address, voting_power: leaf.voting_power + 1, 
        }; // lying about voting power here
        fake_leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        voting_strategy.get_voting_power(timestamp, voter, params.span(), user_params.span());
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', 'ENTRYPOINT_FAILED'))]
    fn lying_address_power() {
        let members = generate_n_members(20);

        let (contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false,
        )
            .unwrap();
        let voting_strategy = IVotingStrategyDispatcher { contract_address: contract };
        let timestamp = 0x1234;
        let index = 2;
        let leaf = *members.at(index);
        let voter = leaf.address;

        let merkle_data = generate_merkle_data(members.span());
        let root = generate_merkle_root(merkle_data.span());
        let proof = generate_proof(merkle_data.span(), index);

        let mut params = array![];
        root.serialize(ref params);

        let mut user_params = array![];
        let fake_leaf = Leaf {
            address: UserAddress::Starknet(contract_address_const::<0x1337>()),
            voting_power: leaf.voting_power,
        }; // lying about address here
        fake_leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        voting_strategy.get_voting_power(timestamp, voter, params.span(), user_params.span());
    }
}
