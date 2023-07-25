#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use starknet::{
        class_hash::Felt252TryIntoClassHash, ContractAddress, syscalls::deploy_syscall, testing,
        contract_address_const, info
    };
    use traits::{Into, TryInto};
    use sx::factory::factory::{Factory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use option::OptionTrait;
    use serde::{Serde};
    use result::ResultTrait;
    use Factory::Factory as FactoryImpl;
    use sx::space::space::Space;
    use integer::u256_from_felt252;
    use sx::utils::types::Strategy;
    use starknet::ClassHash;
    use sx::authenticators::vanilla::{VanillaAuthenticator};
    use sx::execution_strategies::vanilla::VanillaExecutionStrategy;
    use sx::voting_strategies::vanilla::VanillaVotingStrategy;
    use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
    use debug::PrintTrait;
    use debug::ArrayGenericPrintImpl;
    use sx::utils::types::TestValue;

    fn setup() -> (
        ContractAddress, u64, u64, u64, Strategy, Array<Strategy>, Array<ContractAddress>
    ) {
        let owner = contract_address_const::<0x123456789>();
        let max_voting_duration = 2_u64;
        let min_voting_duration = 1_u64;
        let voting_delay = 1_u64;

        let proposal_validation_strategy = TestValue::<Strategy>::test_value();

        let mut voting_strategies = ArrayTrait::<Strategy>::new();
        voting_strategies.append(TestValue::test_value());

        let mut authenticators = ArrayTrait::<ContractAddress>::new();
        authenticators.append(contract_address_const::<0x9990>());

        (
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            voting_strategies,
            authenticators
        )
    }

    fn get_constructor_calldata(
        owner: ContractAddress,
        min_voting_duration: u64,
        max_voting_duration: u64,
        voting_delay: u64,
        proposal_validation_strategy: Strategy,
        voting_strategies: Array<Strategy>,
        authenticators: Array<ContractAddress>
    ) -> Array<felt252> {
        let mut constructor_calldata = array::ArrayTrait::<felt252>::new();
        constructor_calldata.append(owner.into());
        constructor_calldata.append(max_voting_duration.into());
        constructor_calldata.append(min_voting_duration.into());
        constructor_calldata.append(voting_delay.into());
        proposal_validation_strategy.serialize(ref constructor_calldata);
        voting_strategies.serialize(ref constructor_calldata);
        authenticators.serialize(ref constructor_calldata);

        constructor_calldata
    }

    #[test]
    #[available_gas(10000000000)]
    fn test_deploy() {
        let deployer = contract_address_const::<0x1234>();

        testing::set_caller_address(deployer);
        testing::set_contract_address(deployer);

        let (factory_address, _) = deploy_syscall(
            Factory::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            ArrayTrait::<felt252>::new().span(),
            false
        )
            .unwrap();

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let contract_address_salt = 0;

        // Deploy Space 
        let (
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            voting_strategies,
            authenticators
        ) =
            setup();
        let constructor_calldata = get_constructor_calldata(
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            voting_strategies,
            authenticators
        );

        // TODO: check event gets emitted
        let factory_address = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
    }


    #[test]
    #[available_gas(10000000000)]
    fn test_deploy_reuse_salt() {
        let deployer = contract_address_const::<0x1234>();

        testing::set_caller_address(deployer);
        testing::set_contract_address(deployer);

        let mut constructor_calldata = ArrayTrait::<felt252>::new();

        let (factory_address, _) = deploy_syscall(
            Factory::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), false
        )
            .unwrap();

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let contract_address_salt = 0;

        let (
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            voting_strategies,
            authenticators
        ) =
            setup();
        let constructor_calldata = get_constructor_calldata(
            owner,
            min_voting_duration,
            max_voting_duration,
            voting_delay,
            proposal_validation_strategy,
            voting_strategies,
            authenticators
        );

        let factory_address = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
        let factory_address_2 = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
    // TODO: this test should fail but doesn't fail currently because of how the test environment works
    }
}
