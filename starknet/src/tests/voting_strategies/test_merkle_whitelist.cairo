#[cfg(test)]
mod merkle_whitelist_voting_power {
    use array::ArrayTrait;
    use sx::utils::merkle::Leaf;
    use sx::tests::utils::merkle::{
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
    fn valid_proof() {
        let members = generate_n_members(20);

        let (contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
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

        let mut params = ArrayTrait::<felt252>::new();
        root.serialize(ref params);

        let mut user_params = ArrayTrait::<felt252>::new();
        leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        assert(
            voting_strategy
                .get_voting_power(timestamp, voter, params, user_params) == leaf
                .voting_power,
            'Incorrect voting power'
        );
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', 'ENTRYPOINT_FAILED'))]
    fn lying_voting_power() {
        let members = generate_n_members(20);

        let (contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
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

        let mut params = ArrayTrait::<felt252>::new();
        root.serialize(ref params);

        let mut user_params = ArrayTrait::<felt252>::new();
        let fake_leaf = Leaf {
            address: leaf.address, voting_power: leaf.voting_power + 1, 
        }; // lying about voting power here
        fake_leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        voting_strategy.get_voting_power(timestamp, voter, params, user_params);
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', 'ENTRYPOINT_FAILED'))]
    fn lying_address() {
        let members = generate_n_members(20);

        let (contract, _) = deploy_syscall(
            MerkleWhitelistVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
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

        let mut params = ArrayTrait::<felt252>::new();
        root.serialize(ref params);

        let mut user_params = ArrayTrait::<felt252>::new();
        let fake_leaf = Leaf {
            address: UserAddress::Starknet(contract_address_const::<0x1337>()),
            voting_power: leaf.voting_power,
        }; // lying about address here
        fake_leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        voting_strategy.get_voting_power(timestamp, voter, params, user_params);
    }
}
