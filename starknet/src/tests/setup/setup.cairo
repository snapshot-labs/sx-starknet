#[cfg(test)]
mod setup {
    use array::ArrayTrait;
    use starknet::{ContractAddress, contract_address_const};
    use traits::{Into, TryInto};
    use serde::{Serde};
    use result::ResultTrait;
    use option::OptionTrait;
    use sx::types::Strategy;
    use sx::authenticators::vanilla::{VanillaAuthenticator};
    use sx::execution_strategies::vanilla::VanillaExecutionStrategy;
    use sx::voting_strategies::vanilla::VanillaVotingStrategy;
    use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
    use sx::tests::utils::strategy_trait::StrategyImpl;
    use integer::u256_from_felt252;
    use starknet::testing;
    use starknet::syscalls::deploy_syscall;
    use sx::factory::factory::{Factory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use starknet::ClassHash;
    use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};

    #[derive(Drop)]
    struct Config {
        owner: ContractAddress,
        min_voting_duration: u32,
        max_voting_duration: u32,
        voting_delay: u32,
        proposal_validation_strategy: Strategy,
        voting_strategies: Array<Strategy>,
        authenticators: Array<ContractAddress>,
    }

    fn setup() -> Config {
        let deployer = contract_address_const::<0x1234>();
        testing::set_caller_address(deployer);
        testing::set_contract_address(deployer);

        // Space Settings
        let owner = contract_address_const::<0x123456789>();
        let max_voting_duration = 2_u32;
        let min_voting_duration = 1_u32;
        let voting_delay = 1_u32;
        let quorum = u256_from_felt252(1);

        // Deploy Vanilla Authenticator 
        let (vanilla_authenticator_address, _) = deploy_syscall(
            VanillaAuthenticator::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();
        let mut authenticators = ArrayTrait::<ContractAddress>::new();
        authenticators.append(vanilla_authenticator_address);

        // Deploy Vanilla Proposal Validation Strategy
        let (vanilla_proposal_validation_address, _) = deploy_syscall(
            VanillaProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            array![].span(),
            false
        )
            .unwrap();
        let proposal_validation_strategy = StrategyImpl::from_address(
            vanilla_proposal_validation_address
        );

        // Deploy Vanilla Voting Strategy 
        let (vanilla_voting_strategy_address, _) = deploy_syscall(
            VanillaVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();
        let mut voting_strategies = ArrayTrait::<Strategy>::new();
        voting_strategies
            .append(Strategy { address: vanilla_voting_strategy_address, params: array![] });

        // Deploy Vanilla Execution Strategy 
        let mut initializer_calldata = array![];
        quorum.serialize(ref initializer_calldata);
        let (vanilla_execution_strategy_address, _) = deploy_syscall(
            VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            initializer_calldata.span(),
            false
        )
            .unwrap();
        let vanilla_execution_strategy = StrategyImpl::from_address(
            vanilla_execution_strategy_address
        );

        Config {
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            voting_strategies,
            authenticators
        }
    }

    fn get_initialize_calldata(
        owner: @ContractAddress,
        min_voting_duration: @u32,
        max_voting_duration: @u32,
        voting_delay: @u32,
        proposal_validation_strategy: @Strategy,
        voting_strategies: @Array<Strategy>,
        authenticators: @Array<ContractAddress>
    ) -> Array<felt252> {
        // Using empty arrays for all the metadata fields
        let mut initializer_calldata = array![];
        owner.serialize(ref initializer_calldata);
        min_voting_duration.serialize(ref initializer_calldata);
        max_voting_duration.serialize(ref initializer_calldata);
        voting_delay.serialize(ref initializer_calldata);
        proposal_validation_strategy.serialize(ref initializer_calldata);
        ArrayTrait::<felt252>::new().serialize(ref initializer_calldata);
        voting_strategies.serialize(ref initializer_calldata);
        ArrayTrait::<felt252>::new().serialize(ref initializer_calldata);
        authenticators.serialize(ref initializer_calldata);
        ArrayTrait::<felt252>::new().serialize(ref initializer_calldata);
        ArrayTrait::<felt252>::new().serialize(ref initializer_calldata);

        initializer_calldata
    }

    fn deploy(config: @Config) -> (IFactoryDispatcher, ISpaceDispatcher) {
        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let contract_address_salt = 0;

        let (factory_address, _) = deploy_syscall(
            Factory::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
        )
            .unwrap();

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let initializer_calldata = get_initialize_calldata(
            config.owner,
            config.min_voting_duration,
            config.max_voting_duration,
            config.voting_delay,
            config.proposal_validation_strategy,
            config.voting_strategies,
            config.authenticators
        );
        let space_address = factory
            .deploy(space_class_hash, contract_address_salt, initializer_calldata.span());

        let space = ISpaceDispatcher { contract_address: space_address };

        (factory, space)
    }
}
