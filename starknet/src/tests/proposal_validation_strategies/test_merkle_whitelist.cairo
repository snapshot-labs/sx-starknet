#[cfg(test)]
mod merkle_whitelist_proposal_strategy {
    use array::{ArrayTrait, SpanTrait};
    use sx::utils::merkle::Leaf;
    use sx::tests::utils::merkle::{
        generate_merkle_root, generate_n_members, generate_merkle_data, generate_proof
    };
    use sx::proposal_validation_strategies::merkle_whitelist::{
        MerkleWhitelistProposalValidationStrategy
    };
    use sx::interfaces::{
        IProposalValidationStrategy, IProposalValidationStrategyDispatcher,
        IProposalValidationStrategyDispatcherTrait
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::SyscallResult;
    use result::ResultTrait;
    use option::OptionTrait;
    use traits::TryInto;
    use serde::Serde;
    use starknet::contract_address_const;
    use sx::types::UserAddress;

    // Checks that that the leaf at the given index is correclty accepted or rejected (given a certain `threshold`).
    fn check_index(
        index: usize,
        members: Span<Leaf>,
        threshold: u256,
        proposal_validation_strategy: IProposalValidationStrategyDispatcher
    ) {
        let leaf = *members.at(index);
        let proposer = leaf.address;

        let merkle_data = generate_merkle_data(members);
        let root = generate_merkle_root(merkle_data.span());
        let proof = generate_proof(merkle_data.span(), index);

        let mut params = ArrayTrait::<felt252>::new();
        root.serialize(ref params);
        threshold.serialize(ref params);

        let mut user_params = ArrayTrait::<felt252>::new();
        leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        let is_valid = proposal_validation_strategy.validate(proposer, params, user_params);
        if (leaf.voting_power >= threshold) {
            assert(is_valid, 'Proposer got rejected');
        } else {
            assert(!is_valid, 'Proposer got accepted');
        }
    }

    #[test]
    #[available_gas(1000000000)]
    fn just_enough_vp() {
        let members = generate_n_members(20);
        let threshold = 3_u256; // Voting power required to submit a proposal

        let (contract, _) = deploy_syscall(
            MerkleWhitelistProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false,
        )
            .unwrap();
        let proposal_validation_strategy = IProposalValidationStrategyDispatcher {
            contract_address: contract
        };

        check_index(
            2, members.span(), threshold, proposal_validation_strategy
        ); // Index 2 has voting power 3
    }

    #[test]
    #[available_gas(1000000000)]
    fn more_than_enough_vp() {
        let members = generate_n_members(20);
        let threshold = 3_u256; // Voting power required to submit a proposal

        let (contract, _) = deploy_syscall(
            MerkleWhitelistProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false,
        )
            .unwrap();
        let proposal_validation_strategy = IProposalValidationStrategyDispatcher {
            contract_address: contract
        };

        check_index(
            3, members.span(), threshold, proposal_validation_strategy
        ); // Index 3 has voting power 4
    }

    #[test]
    #[available_gas(1000000000)]
    fn not_enough_vp() {
        let members = generate_n_members(20);
        let threshold = 3_u256; // Voting power required to submit a proposal

        let (contract, _) = deploy_syscall(
            MerkleWhitelistProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false,
        )
            .unwrap();
        let proposal_validation_strategy = IProposalValidationStrategyDispatcher {
            contract_address: contract
        };

        check_index(
            1, members.span(), threshold, proposal_validation_strategy
        ); // Index 1 has voting power 2
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', 'ENTRYPOINT_FAILED'))]
    fn lying_voting_power() {
        let members = generate_n_members(20);
        let threshold = 0_u256;

        let (contract, _) = deploy_syscall(
            MerkleWhitelistProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false,
        )
            .unwrap();
        let proposal_validation_strategy = IProposalValidationStrategyDispatcher {
            contract_address: contract
        };
        let timestamp = 0x1234;
        let index = 2;
        let leaf = *members.at(index);
        let voter = leaf.address;

        let merkle_data = generate_merkle_data(members.span());
        let root = generate_merkle_root(merkle_data.span());
        let proof = generate_proof(merkle_data.span(), index);

        let mut params = ArrayTrait::<felt252>::new();
        root.serialize(ref params);
        threshold.serialize(ref params);

        let mut user_params = ArrayTrait::<felt252>::new();
        let fake_leaf = Leaf {
            address: leaf.address, voting_power: leaf.voting_power + 1, 
        }; // lying about voting power here
        fake_leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        proposal_validation_strategy.validate(voter, params, user_params);
    }

    #[test]
    #[available_gas(1000000000)]
    #[should_panic(expected: ('Merkle: Invalid proof', 'ENTRYPOINT_FAILED'))]
    fn lying_address() {
        let members = generate_n_members(20);
        let threshold = 0_u256;

        let (contract, _) = deploy_syscall(
            MerkleWhitelistProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false,
        )
            .unwrap();
        let proposal_validation_strategy = IProposalValidationStrategyDispatcher {
            contract_address: contract
        };
        let timestamp = 0x1234;
        let index = 2;
        let leaf = *members.at(index);
        let proposer = leaf.address;

        let merkle_data = generate_merkle_data(members.span());
        let root = generate_merkle_root(merkle_data.span());
        let proof = generate_proof(merkle_data.span(), index);

        let mut params = ArrayTrait::<felt252>::new();
        root.serialize(ref params);
        threshold.serialize(ref params);

        let mut user_params = ArrayTrait::<felt252>::new();
        let fake_leaf = Leaf {
            address: UserAddress::Starknet(contract_address_const::<0x1337>()),
            voting_power: leaf.voting_power + 1,
        }; // lying about voting power here
        fake_leaf.serialize(ref user_params);
        proof.serialize(ref user_params);

        proposal_validation_strategy.validate(proposer, params, user_params);
    }
}
