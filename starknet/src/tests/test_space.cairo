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
    use sx::authenticators::vanilla::{
        VanillaAuthenticator, IVanillaAuthenticatorDispatcher, IVanillaAuthenticatorDispatcherTrait
    };
    use sx::execution_strategies::vanilla::VanillaExecutionStrategy;
    use sx::voting_strategies::vanilla::VanillaVotingStrategy;
    use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
    use sx::tests::mocks::proposal_validation_always_fail::AlwaysFailProposalValidationStrategy;
    use sx::tests::setup::setup::setup::{setup, deploy};
    use sx::types::{
        UserAddress, Strategy, IndexedStrategy, Choice, FinalizationStatus, Proposal,
        UpdateSettingsCalldataImpl
    };
    use sx::tests::utils::strategy_trait::{StrategyImpl};
    use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};

    use Space::Space as SpaceImpl;

    #[test]
    #[available_gas(100000000)]
    fn initialize() {
        let deployer = contract_address_const::<0xdead>();

        testing::set_caller_address(deployer);
        testing::set_contract_address(deployer);
        // Space Settings
        let owner = contract_address_const::<0x123456789>();
        let min_voting_duration = 1_u32;
        let max_voting_duration = 2_u32;
        let voting_delay = 1_u32;

        // Deploy Vanilla Authenticator 
        let (vanilla_authenticator_address, _) = deploy_syscall(
            VanillaAuthenticator::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();
        let mut authenticators = array![vanilla_authenticator_address];

        // Deploy Vanilla Proposal Validation Strategy
        let (vanilla_proposal_validation_address, _) = deploy_syscall(
            VanillaProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();
        let vanilla_proposal_validation_strategy = StrategyImpl::from_address(
            vanilla_proposal_validation_address
        );

        // Deploy Vanilla Voting Strategy 
        let (vanilla_voting_strategy_address, _) = deploy_syscall(
            VanillaVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();
        let mut voting_strategies = array![
            Strategy { address: vanilla_voting_strategy_address, params: array![] }
        ];

        // Deploy Space 
        let (space_address, _) = deploy_syscall(
            Space::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        let space = ISpaceDispatcher { contract_address: space_address };

        space
            .initialize(
                owner,
                min_voting_duration,
                max_voting_duration,
                voting_delay,
                vanilla_proposal_validation_strategy.clone(),
                array![],
                voting_strategies,
                array![],
                authenticators,
                array![],
                array![]
            );

        assert(space.owner() == owner, 'owner incorrect');
        assert(space.min_voting_duration() == min_voting_duration, 'min incorrect');
        assert(space.max_voting_duration() == max_voting_duration, 'max incorrect');
        assert(space.voting_delay() == voting_delay, 'voting delay incorrect');
        assert(
            space.proposal_validation_strategy() == vanilla_proposal_validation_strategy,
            'proposal validation incorrect'
        );
    }

    #[test]
    #[available_gas(100000000)]
    #[should_panic(expected: ('Already Initialized', 'ENTRYPOINT_FAILED'))]
    fn reinitialize() {
        let deployer = contract_address_const::<0xdead>();

        testing::set_caller_address(deployer);
        testing::set_contract_address(deployer);
        // Space Settings
        let owner = contract_address_const::<0x123456789>();
        let min_voting_duration = 1_u32;
        let max_voting_duration = 2_u32;
        let voting_delay = 1_u32;

        // Deploy Vanilla Authenticator 
        let (vanilla_authenticator_address, _) = deploy_syscall(
            VanillaAuthenticator::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false
        )
            .unwrap();
        let mut authenticators = ArrayTrait::<ContractAddress>::new();
        authenticators.append(vanilla_authenticator_address);

        // Deploy Vanilla Proposal Validation Strategy
        let (vanilla_proposal_validation_address, _) = deploy_syscall(
            VanillaProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false
        )
            .unwrap();
        let vanilla_proposal_validation_strategy = StrategyImpl::from_address(
            vanilla_proposal_validation_address
        );

        // Deploy Vanilla Voting Strategy 
        let (vanilla_voting_strategy_address, _) = deploy_syscall(
            VanillaVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array::ArrayTrait::<felt252>::new().span(),
            false
        )
            .unwrap();
        let mut voting_strategies = ArrayTrait::<Strategy>::new();
        voting_strategies
            .append(
                Strategy {
                    address: vanilla_voting_strategy_address, params: ArrayTrait::<felt252>::new()
                }
            );

        // Deploy Space 
        let (space_address, _) = deploy_syscall(
            Space::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        let space = ISpaceDispatcher { contract_address: space_address };

        space
            .initialize(
                owner,
                min_voting_duration,
                max_voting_duration,
                voting_delay,
                vanilla_proposal_validation_strategy.clone(),
                array![],
                voting_strategies.clone(),
                array![],
                authenticators.clone(),
                array![],
                array![]
            );

        // Atempting to call the initialize function again
        space
            .initialize(
                owner,
                min_voting_duration,
                max_voting_duration,
                voting_delay,
                vanilla_proposal_validation_strategy,
                array![],
                voting_strategies,
                array![],
                authenticators,
                array![],
                array![]
            );
    }

    #[test]
    #[available_gas(10000000000)]
    fn propose_update_vote_execute() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = array![];
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
        let author = UserAddress::Starknet(contract_address_const::<0x5678>());
        let mut propose_calldata = array![];
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);

        assert(space.next_proposal_id() == 2_u256, 'next_proposal_id should be 2');

        let proposal = space.proposals(u256_from_felt252(1));
        let timestamp = info::get_block_timestamp().try_into().unwrap();
        let expected_proposal = Proposal {
            start_timestamp: timestamp + 1_u32,
            min_end_timestamp: timestamp + 2_u32,
            max_end_timestamp: timestamp + 3_u32,
            execution_payload_hash: poseidon::poseidon_hash_span(
                vanilla_execution_strategy.params.span()
            ),
            execution_strategy: vanilla_execution_strategy.address,
            author: author,
            finalization_status: FinalizationStatus::Pending(()),
            active_voting_strategies: u256_from_felt252(1)
        };
        assert(proposal == expected_proposal, 'proposal state');

        // Update Proposal
        let mut update_calldata = array![];
        author.serialize(ref update_calldata);
        let proposal_id = u256_from_felt252(1);
        proposal_id.serialize(ref update_calldata);
        // Keeping the same execution strategy contract but changing the payload
        let mut new_payload = array![1];
        let execution_strategy = Strategy {
            address: vanilla_execution_strategy.address, params: new_payload.clone()
        };
        execution_strategy.serialize(ref update_calldata);
        ArrayTrait::<felt252>::new().serialize(ref update_calldata);

        authenticator
            .authenticate(space.contract_address, UPDATE_PROPOSAL_SELECTOR, update_calldata);

        testing::set_block_timestamp(config.voting_delay.into());

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = u256_from_felt252(1);
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        // Vote on Proposal
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);

        testing::set_block_timestamp(
            config.voting_delay.into() + config.max_voting_duration.into()
        );

        // Execute Proposal
        space.execute(u256_from_felt252(1), new_payload);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Proposal is not valid', 'ENTRYPOINT_FAILED'))]
    fn propose_failed_validation() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0)
        };

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = array![];
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

        assert(space.next_proposal_id() == 1_u256, 'next_proposal_id should be 1');

        // Replace proposal validation strategy with one that always fails
        let (strategy_address, _) = deploy_syscall(
            AlwaysFailProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();

        testing::set_caller_address(config.owner);
        testing::set_contract_address(config.owner);
        let mut input = UpdateSettingsCalldataImpl::default();
        input.proposal_validation_strategy = StrategyImpl::from_address(strategy_address);

        space.update_settings(input);

        let author = UserAddress::Starknet(contract_address_const::<0x5678>());
        let mut propose_calldata = array![];
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Try to create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Already finalized', 'ENTRYPOINT_FAILED'))]
    fn execute_already_finalized() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = array![];
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
        let author = UserAddress::Starknet(contract_address_const::<0x5678>());
        let mut propose_calldata = array![];
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);

        assert(space.next_proposal_id() == 2_u256, 'next_proposal_id should be 2');

        testing::set_block_timestamp(config.voting_delay.into());

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = u256_from_felt252(1);
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        // Vote on Proposal
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);

        testing::set_block_timestamp(
            config.voting_delay.into() + config.max_voting_duration.into()
        );

        // Execute Proposal
        space.execute(u256_from_felt252(1), vanilla_execution_strategy.params.clone());

        // Execute a second time
        space.execute(u256_from_felt252(1), vanilla_execution_strategy.params.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Proposal has been finalized', 'ENTRYPOINT_FAILED'))]
    fn cancel() {
        let relayer = contract_address_const::<0x1234>();
        let config = setup();
        let (factory, space) = deploy(@config);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0)
        };

        let quorum = u256_from_felt252(1);
        let mut constructor_calldata = array![];
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
        let mut propose_calldata = array![];
        let author = UserAddress::Starknet(contract_address_const::<0x5678>());
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);
        let proposal_id = u256_from_felt252(1);

        testing::set_block_timestamp(config.voting_delay.into());
        let proposal = space.proposals(proposal_id);
        assert(proposal.finalization_status == FinalizationStatus::Pending(()), 'pending');

        // Cancel Proposal
        testing::set_caller_address(config.owner);
        testing::set_contract_address(config.owner);
        space.cancel_proposal(proposal_id);

        let proposal = space.proposals(proposal_id);
        assert(proposal.finalization_status == FinalizationStatus::Cancelled(()), 'cancelled');

        // Try to cast vote on Cancelled Proposal
        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Zero Address', 'ENTRYPOINT_FAILED'))]
    fn propose_zero_address() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

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
        // author is the zero address
        let author = UserAddress::Starknet(contract_address_const::<0x0>());
        let mut propose_calldata = array::ArrayTrait::<felt252>::new();
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Zero Address', 'ENTRYPOINT_FAILED'))]
    fn update_zero_address() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

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
        // author is the zero address
        let author = UserAddress::Starknet(contract_address_const::<0x0>());
        let mut propose_calldata = array::ArrayTrait::<felt252>::new();
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);

        // Update Proposal
        let mut update_calldata = array::ArrayTrait::<felt252>::new();
        author.serialize(ref update_calldata);
        let proposal_id = u256_from_felt252(1);
        proposal_id.serialize(ref update_calldata);
        // Keeping the same execution strategy contract but changing the payload
        let mut new_payload = ArrayTrait::<felt252>::new();
        new_payload.append(1);
        let execution_strategy = Strategy {
            address: vanilla_execution_strategy.address, params: new_payload
        };
        execution_strategy.serialize(ref update_calldata);
        ArrayTrait::<felt252>::new().serialize(ref update_calldata);

        authenticator
            .authenticate(space.contract_address, UPDATE_PROPOSAL_SELECTOR, update_calldata);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Zero Address', 'ENTRYPOINT_FAILED'))]
    fn vote_zero_address() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

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
        let author = UserAddress::Starknet(contract_address_const::<0x5678>());
        let mut propose_calldata = array::ArrayTrait::<felt252>::new();
        author.serialize(ref propose_calldata);
        vanilla_execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);

        // Update Proposal
        let mut update_calldata = array::ArrayTrait::<felt252>::new();
        author.serialize(ref update_calldata);
        let proposal_id = u256_from_felt252(1);
        proposal_id.serialize(ref update_calldata);
        // Keeping the same execution strategy contract but changing the payload
        let mut new_payload = ArrayTrait::<felt252>::new();
        new_payload.append(1);
        let execution_strategy = Strategy {
            address: vanilla_execution_strategy.address, params: new_payload
        };
        execution_strategy.serialize(ref update_calldata);
        ArrayTrait::<felt252>::new().serialize(ref update_calldata);

        authenticator
            .authenticate(space.contract_address, UPDATE_PROPOSAL_SELECTOR, update_calldata);

        // Increasing block block_number by 1 to pass voting delay
        testing::set_block_number(1_u64);

        let mut vote_calldata = array::ArrayTrait::<felt252>::new();
        // Voter is the zero address
        let voter = UserAddress::Starknet(contract_address_const::<0x0>());
        voter.serialize(ref vote_calldata);
        let proposal_id = u256_from_felt252(1);
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = ArrayTrait::<IndexedStrategy>::new();
        user_voting_strategies
            .append(IndexedStrategy { index: 0_u8, params: ArrayTrait::<felt252>::new() });
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        // Vote on Proposal
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
    }
}
