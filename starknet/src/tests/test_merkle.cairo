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
    use sx::tests::utils::merkle::{
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
        let proof = ArrayTrait::new();
        assert_valid_proof(root, leaf, proof.span());
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', ))]
    fn invalid_extra_node() {
        let mut members = ArrayTrait::new();
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<5>()), voting_power: 5
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<4>()), voting_power: 4
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<3>()), voting_power: 3
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<2>()), voting_power: 2
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<1>()), voting_power: 1
                }
            );
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
        let mut members = ArrayTrait::new();
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<5>()), voting_power: 5
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<4>()), voting_power: 4
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<3>()), voting_power: 3
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<2>()), voting_power: 2
                }
            );
        members
            .append(
                Leaf {
                    address: UserAddress::Starknet(contract_address_const::<1>()), voting_power: 1
                }
            );
        let merkle_data = generate_merkle_data(members.span());

        let root = generate_merkle_root(merkle_data.span());
        let index = 2;
        let proof = generate_proof(merkle_data.span(), index);
        let fake_proof = replace_first_element(proof.span(), 0x1337);

        assert_valid_proof(root, *members.at(index), fake_proof.span());
    }
}

