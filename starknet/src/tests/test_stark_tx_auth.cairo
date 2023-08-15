#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use starknet::{
        ContractAddress, syscalls::deploy_syscall, testing, contract_address_const, info
    };
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use integer::u256_from_felt252;
    use clone::Clone;
    use serde::{Serde};
    use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::authenticators::stark_tx::{
        StarkTxAuthenticator, IStarkTxAuthenticatorDispatcher, IStarkTxAuthenticatorDispatcherTrait
    };
    use sx::execution_strategies::vanilla::VanillaExecutionStrategy;
    use sx::voting_strategies::vanilla::VanillaVotingStrategy;
    use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
    use sx::tests::setup::setup::setup::{setup, deploy};
    use sx::types::{
        UserAddress, Strategy, IndexedStrategy, Choice, FinalizationStatus, Proposal,
        UpdateSettingsCalldataImpl, UpdateSettingsCalldata
    };
    use sx::tests::utils::strategy_trait::{StrategyImpl};

    fn setup_stark_tx_auth(
        space: ISpaceDispatcher, owner: ContractAddress
    ) -> IStarkTxAuthenticatorDispatcher {
        // Deploy Stark Tx Authenticator and whitelist in Space
        let (stark_tx_authenticator_address, _) = deploy_syscall(
            StarkTxAuthenticator::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        let authenticator = IStarkTxAuthenticatorDispatcher {
            contract_address: stark_tx_authenticator_address, 
        };
        let mut updateSettingsCalldata: UpdateSettingsCalldata =
            UpdateSettingsCalldataImpl::default();
        updateSettingsCalldata.authenticators_to_add = array![stark_tx_authenticator_address];
        testing::set_contract_address(owner);
        space.update_settings(updateSettingsCalldata);

        authenticator
    }

    #[test]
    #[available_gas(10000000000)]
    fn test_propose_update_vote() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let authenticator = setup_stark_tx_auth(space, config.owner);

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = ArrayTrait::<felt252>::new();
        quorum.serialize(ref constructor_calldata);

        let (vanilla_execution_strategy_address, _) = deploy_syscall(
            VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false
        )
            .unwrap();
        let vanilla_execution_strategy = StrategyImpl::from_address(
            vanilla_execution_strategy_address
        );
        let author = contract_address_const::<0x5678>();

        // Create Proposal
        testing::set_contract_address(author);
        authenticator
            .authenticate_propose(
                space.contract_address,
                author,
                vanilla_execution_strategy,
                ArrayTrait::<felt252>::new(),
                ArrayTrait::<felt252>::new()
            );

        assert(
            space.next_proposal_id() == u256 { low: 2_u128, high: 0_u128 },
            'next_proposal_id should be 2'
        );

        // Update Proposal

        let proposal_id = u256_from_felt252(1);
        // Keeping the same execution strategy contract but changing the payload
        let mut new_payload = ArrayTrait::<felt252>::new();
        new_payload.append(1);
        let new_execution_strategy = Strategy {
            address: vanilla_execution_strategy_address, params: new_payload.clone()
        };

        testing::set_contract_address(author);
        authenticator
            .authenticate_update_proposal(
                space.contract_address,
                author,
                proposal_id,
                new_execution_strategy,
                ArrayTrait::<felt252>::new()
            );

        // Increasing block block_number by 1 to pass voting delay
        testing::set_block_number(1_u64);

        let voter = contract_address_const::<0x8765>();
        let choice = Choice::For(());
        let mut user_voting_strategies = ArrayTrait::<IndexedStrategy>::new();
        user_voting_strategies
            .append(IndexedStrategy { index: 0_u8, params: ArrayTrait::<felt252>::new() });

        // Vote on Proposal
        testing::set_contract_address(voter);
        authenticator
            .authenticate_vote(
                space.contract_address,
                voter,
                proposal_id,
                choice,
                user_voting_strategies,
                ArrayTrait::<felt252>::new()
            );

        testing::set_block_number(2_u64);

        // Execute Proposal
        space.execute(u256_from_felt252(1), new_payload);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid Caller', 'ENTRYPOINT_FAILED'))]
    fn test_propose_invalid_caller() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let authenticator = setup_stark_tx_auth(space, config.owner);

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = ArrayTrait::<felt252>::new();
        quorum.serialize(ref constructor_calldata);

        let (vanilla_execution_strategy_address, _) = deploy_syscall(
            VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false
        )
            .unwrap();
        let vanilla_execution_strategy = StrategyImpl::from_address(
            vanilla_execution_strategy_address
        );
        let author = contract_address_const::<0x5678>();

        // Create Proposal not from author account
        testing::set_contract_address(config.owner);
        authenticator
            .authenticate_propose(
                space.contract_address,
                author,
                vanilla_execution_strategy,
                ArrayTrait::<felt252>::new(),
                ArrayTrait::<felt252>::new()
            );
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid Caller', 'ENTRYPOINT_FAILED'))]
    fn test_update_proposal_invalid_caller() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let authenticator = setup_stark_tx_auth(space, config.owner);

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = ArrayTrait::<felt252>::new();
        quorum.serialize(ref constructor_calldata);

        let (vanilla_execution_strategy_address, _) = deploy_syscall(
            VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false
        )
            .unwrap();
        let vanilla_execution_strategy = StrategyImpl::from_address(
            vanilla_execution_strategy_address
        );
        let author = contract_address_const::<0x5678>();

        // Create Proposal
        testing::set_contract_address(author);
        authenticator
            .authenticate_propose(
                space.contract_address,
                author,
                vanilla_execution_strategy,
                ArrayTrait::<felt252>::new(),
                ArrayTrait::<felt252>::new()
            );

        assert(
            space.next_proposal_id() == u256 { low: 2_u128, high: 0_u128 },
            'next_proposal_id should be 2'
        );

        // Update Proposal

        let proposal_id = u256_from_felt252(1);
        // Keeping the same execution strategy contract but changing the payload
        let mut new_payload = ArrayTrait::<felt252>::new();
        new_payload.append(1);
        let new_execution_strategy = Strategy {
            address: vanilla_execution_strategy_address, params: new_payload.clone()
        };

        // Update proposal not from author account
        testing::set_contract_address(config.owner);
        authenticator
            .authenticate_update_proposal(
                space.contract_address,
                author,
                proposal_id,
                new_execution_strategy,
                ArrayTrait::<felt252>::new()
            );
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid Caller', 'ENTRYPOINT_FAILED'))]
    fn test_vote_invalid_caller() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let authenticator = setup_stark_tx_auth(space, config.owner);

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = ArrayTrait::<felt252>::new();
        quorum.serialize(ref constructor_calldata);

        let (vanilla_execution_strategy_address, _) = deploy_syscall(
            VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false
        )
            .unwrap();
        let vanilla_execution_strategy = StrategyImpl::from_address(
            vanilla_execution_strategy_address
        );
        let author = contract_address_const::<0x5678>();

        // Create Proposal
        testing::set_contract_address(author);
        authenticator
            .authenticate_propose(
                space.contract_address,
                author,
                vanilla_execution_strategy,
                ArrayTrait::<felt252>::new(),
                ArrayTrait::<felt252>::new()
            );

        assert(
            space.next_proposal_id() == u256 { low: 2_u128, high: 0_u128 },
            'next_proposal_id should be 2'
        );

        // Update Proposal

        let proposal_id = u256_from_felt252(1);
        // Keeping the same execution strategy contract but changing the payload
        let mut new_payload = ArrayTrait::<felt252>::new();
        new_payload.append(1);
        let new_execution_strategy = Strategy {
            address: vanilla_execution_strategy_address, params: new_payload.clone()
        };

        testing::set_contract_address(author);
        authenticator
            .authenticate_update_proposal(
                space.contract_address,
                author,
                proposal_id,
                new_execution_strategy,
                ArrayTrait::<felt252>::new()
            );

        // Increasing block block_number by 1 to pass voting delay
        testing::set_block_number(1_u64);

        let voter = contract_address_const::<0x8765>();
        let choice = Choice::For(());
        let mut user_voting_strategies = ArrayTrait::<IndexedStrategy>::new();
        user_voting_strategies
            .append(IndexedStrategy { index: 0_u8, params: ArrayTrait::<felt252>::new() });

        // Vote on Proposal not from voter account
        testing::set_contract_address(config.owner);
        authenticator
            .authenticate_vote(
                space.contract_address,
                voter,
                proposal_id,
                choice,
                user_voting_strategies,
                ArrayTrait::<felt252>::new()
            );
    }
}
