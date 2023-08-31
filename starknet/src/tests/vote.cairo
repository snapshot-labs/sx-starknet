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
    use sx::tests::mocks::executor::ExecutorWithoutTxExecutionStrategy;
    use sx::voting_strategies::vanilla::VanillaVotingStrategy;
    use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
    use sx::tests::mocks::proposal_validation_always_fail::AlwaysFailProposalValidationStrategy;
    use sx::tests::mocks::no_voting_power::NoVotingPowerVotingStrategy;
    use sx::tests::setup::setup::setup::{setup, deploy};
    use sx::types::{
        UserAddress, Strategy, IndexedStrategy, Choice, FinalizationStatus, Proposal,
        UpdateSettingsCalldataImpl
    };
    use sx::tests::utils::strategy_trait::{StrategyImpl};
    use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};

    use Space::Space as SpaceImpl;

    fn get_execution_strategy() -> Strategy {
        let mut constructor_calldata = array![];

        let (execution_strategy_address, _) = deploy_syscall(
            ExecutorWithoutTxExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false
        )
            .unwrap();
        let strategy = StrategyImpl::from_address(execution_strategy_address);
        strategy
    }

    fn create_proposal(
        authenticator: IVanillaAuthenticatorDispatcher,
        space: ISpaceDispatcher,
        execution_strategy: Strategy
    ) {
        let author = UserAddress::Starknet(contract_address_const::<0x5678>());
        let mut propose_calldata = array![];
        author.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);
        execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        // Create Proposal
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);
    }

    #[test]
    #[available_gas(10000000000)]
    fn vote_for() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Increasing block timestamp pass voting delay
        testing::set_block_timestamp(config.voting_delay);

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
        assert(space.vote_registry(proposal_id, voter) == true, 'vote registry incorrect');
        assert(space.vote_power(proposal_id, Choice::For(())) == 1, 'Vote power should be 1');
        assert(space.vote_power(proposal_id, Choice::Against(())) == 0, 'Vote power should be 0');
        assert(space.vote_power(proposal_id, Choice::Abstain(())) == 0, 'Vote power should be 0');
    // TODO : check event
    }

    #[test]
    #[available_gas(10000000000)]
    fn vote_against() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Increasing block timestamp pass voting delay
        testing::set_block_timestamp(config.voting_delay);

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::Against(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
        assert(space.vote_registry(proposal_id, voter) == true, 'vote registry incorrect');
        assert(space.vote_power(proposal_id, Choice::For(())) == 0, 'Vote power should be 0');
        assert(space.vote_power(proposal_id, Choice::Against(())) == 1, 'Vote power should be 1');
        assert(space.vote_power(proposal_id, Choice::Abstain(())) == 0, 'Vote power should be 0');
    // TODO : check event
    }

    #[test]
    #[available_gas(10000000000)]
    fn vote_abstain() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Increasing block timestamp by voting delay
        testing::set_block_timestamp(config.voting_delay);

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::Abstain(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
        assert(space.vote_registry(proposal_id, voter) == true, 'vote registry incorrect');
        assert(space.vote_power(proposal_id, Choice::For(())) == 0, 'Vote power should be 0');
        assert(space.vote_power(proposal_id, Choice::Against(())) == 0, 'Vote power should be 0');
        assert(space.vote_power(proposal_id, Choice::Abstain(())) == 1, 'Vote power should be 1');
    // TODO : check event
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Voting period has not started', 'ENTRYPOINT_FAILED'))]
    fn vote_too_early() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Do NOT increase block timestamp 

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
    // TODO : check event
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Voting period has ended', 'ENTRYPOINT_FAILED'))]
    fn vote_too_late() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Fast forward to end of voting period
        testing::set_block_timestamp(config.voting_delay + config.max_voting_duration);

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
    // TODO : check event
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Proposal has been finalized', 'ENTRYPOINT_FAILED'))]
    fn vote_finalized_proposal() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        testing::set_block_timestamp(config.voting_delay);

        space
            .execute(
                1, array![]
            ); // Execute the proposal (will work because execution strategy doesn't check for finalization status or quorum)

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
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
    #[should_panic(expected: ('Caller is not an authenticator', 'ENTRYPOINT_FAILED'))]
    fn vote_without_authenticator() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Fast forward to end of voting period
        testing::set_block_timestamp(config.voting_delay + config.max_voting_duration);

        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        let proposal_id = 1_u256;
        let choice = Choice::For(());
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        let metadata_uri = array![];

        space.vote(voter, proposal_id, choice, user_voting_strategies, metadata_uri);
    // TODO : check event
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Voter has already voted', 'ENTRYPOINT_FAILED'))]
    fn vote_twice() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        create_proposal(authenticator, space, execution_strategy);

        // Increasing block timestamp pass voting delay
        testing::set_block_timestamp(config.voting_delay);

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata.clone());
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('User has no voting power', 'ENTRYPOINT_FAILED'))]
    fn vote_no_voting_power() {
        let config = setup();
        let (factory, space) = deploy(@config);

        let execution_strategy = get_execution_strategy();

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        let (no_voting_power_contract, _) = deploy_syscall(
            NoVotingPowerVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();
        let no_voting_power_strategy = StrategyImpl::from_address(no_voting_power_contract);

        let mut input = UpdateSettingsCalldataImpl::default();
        input.voting_strategies_to_add = array![no_voting_power_strategy];

        testing::set_contract_address(config.owner);
        space.update_settings(input);

        create_proposal(authenticator, space, execution_strategy);

        // Increasing block timestamp pass voting delay
        testing::set_block_timestamp(config.voting_delay);

        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![
            IndexedStrategy { index: 1_u8, params: array![] }
        ]; // index 1
        user_voting_strategies.serialize(ref vote_calldata);
        ArrayTrait::<felt252>::new().serialize(ref vote_calldata);

        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);
    }
}
