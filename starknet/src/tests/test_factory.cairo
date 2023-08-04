#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use starknet::{syscalls::deploy_syscall, testing, contract_address_const, };
    use traits::TryInto;
    use sx::factory::factory::{Factory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use option::OptionTrait;
    use result::ResultTrait;
    use sx::space::space::Space;
    use sx::types::Strategy;
    use starknet::ClassHash;

    use sx::tests::setup::setup::setup::{setup, get_constructor_calldata, deploy};

    #[test]
    #[available_gas(10000000000)]
    fn test_deploy() {
        // Deploy Space 
        let config = setup();

        // TODO: check event gets emitted
        deploy(@config);
    }


    #[test]
    #[available_gas(10000000000)]
    fn test_deploy_reuse_salt() {
        let mut constructor_calldata = ArrayTrait::<felt252>::new();

        let (factory_address, _) = deploy_syscall(
            Factory::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), false
        )
            .unwrap();

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let contract_address_salt = 0;

        let config = setup();
        let constructor_calldata = get_constructor_calldata(
            @config.owner,
            @config.min_voting_duration,
            @config.max_voting_duration,
            @config.voting_delay,
            @config.proposal_validation_strategy,
            @config.voting_strategies,
            @config.authenticators
        );

        let space_address = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
        let space_address_2 = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
    // TODO: this test should fail but doesn't fail currently because of how the test environment works
    }
}
