#[cfg(test)]
mod setup {
    use starknet::{ContractAddress, contract_address_const};
    use sx::types::Strategy;
    use sx::tests::mocks::vanilla_authenticator::{VanillaAuthenticator};
    use sx::tests::mocks::vanilla_execution_strategy::VanillaExecutionStrategy;
    use sx::tests::mocks::vanilla_voting_strategy::VanillaVotingStrategy;
    use sx::tests::mocks::vanilla_proposal_validation::VanillaProposalValidationStrategy;
    use sx::tests::utils::strategy_trait::StrategyImpl;
    use integer::u256_from_felt252;
    use starknet::testing;
    use starknet::syscalls::deploy_syscall;
    use sx::factory::factory::{Factory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use starknet::ClassHash;
    use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};
    use debug::PrintTrait;

    #[derive(Drop, Serde)]
    struct Config {
        owner: ContractAddress,
        min_voting_duration: u32,
        max_voting_duration: u32,
        voting_delay: u32,
        proposal_validation_strategy: Strategy,
        proposal_validation_strategy_metadata_uri: Array<felt252>,
        voting_strategies: Array<Strategy>,
        voting_strategies_metadata_uris: Array<Array<felt252>>,
        authenticators: Array<ContractAddress>,
        metadata_uri: Array<felt252>,
        dao_uri: Array<felt252>,
    }

    trait ConfigTrait {
        fn get_initialize_calldata(self: @Config) -> Array<felt252>;
    }

    impl ConfigImpl of ConfigTrait {
        fn get_initialize_calldata(self: @Config) -> Array<felt252> {
            let mut calldata = array![];
            self.serialize(ref calldata);
            calldata
        }
    }

    fn setup() -> Config {
        let deployer = contract_address_const::<0x1234>();
        testing::set_caller_address(deployer);
        testing::set_contract_address(deployer);

        // Space Settings
        let owner = contract_address_const::<0x123456789>();
        let max_voting_duration = 2;
        let min_voting_duration = 1;
        let voting_delay = 1;
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

        let proposal_validation_strategy_metadata_uri = array!['https:://rick.roll'];
        let voting_strategies_metadata_uris = array![array![]];
        let dao_uri = array!['https://dao.uri'];
        let metadata_uri = array!['https://metadata.uri'];

        Config {
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            proposal_validation_strategy_metadata_uri,
            voting_strategies,
            voting_strategies_metadata_uris,
            authenticators,
            metadata_uri,
            dao_uri,
        }
    }

    fn deploy(config: @Config) -> (IFactoryDispatcher, ISpaceDispatcher) {
        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let contract_address_salt = 0;

        let factory_address =
            match deploy_syscall(
                Factory::TEST_CLASS_HASH.try_into().unwrap(), 0, array![].span(), false
            ) {
            Result::Ok((address, _)) => address,
            Result::Err(e) => {
                e.print();
                panic_with_felt252('deploy failed');
                contract_address_const::<0>()
            }
        };

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let mut initializer_calldata = config.get_initialize_calldata();
        let space_address =
            match factory
                .deploy(space_class_hash, contract_address_salt, initializer_calldata.span()) {
            Result::Ok(address) => address,
            Result::Err(e) => {
                e.print();
                panic_with_felt252('deploy failed');
                contract_address_const::<0>()
            },
        };

        let space = ISpaceDispatcher { contract_address: space_address };

        (factory, space)
    }
}
