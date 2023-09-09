#[cfg(test)]
mod tests {
    use starknet::{syscalls, testing, ContractAddress};
    use sx::factory::factory::{Factory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use sx::space::space::Space;
    use sx::types::{Strategy};
    use starknet::ClassHash;
    use sx::tests::setup::setup::setup::{setup, Config, ConfigTrait, deploy};
    use openzeppelin::tests::utils;
    use sx::space::space::Space::SpaceCreated;
    use sx::factory::factory::Factory::NewContractDeployed;

    fn assert_space_event_is_correct(
        event: SpaceCreated, config: Config, space_address: ContractAddress
    ) {
        assert(event.space == space_address, 'space');
        assert(event.owner == config.owner, 'owner');
        assert(event.min_voting_duration == config.min_voting_duration, 'min_voting_duration');
        assert(event.max_voting_duration == config.max_voting_duration, 'max_voting_duration');
        assert(event.voting_delay == config.voting_delay, 'voting_delay');
        assert(
            event.proposal_validation_strategy == config.proposal_validation_strategy,
            'proposal_validation_strategy'
        );
        assert(
            event
                .proposal_validation_strategy_metadata_uri == config
                .proposal_validation_strategy_metadata_uri
                .span(),
            'prop_val_strat_metadata'
        );
        assert(event.voting_strategies == config.voting_strategies.span(), 'voting_strategies');
        assert(
            event.voting_strategy_metadata_uris == config.voting_strategies_metadata_uris.span(),
            'voting_strat_metadata'
        );
        assert(event.authenticators == config.authenticators.span(), 'authenticators');
        assert(event.metadata_uri == config.metadata_uri.span(), 'metadata_uri');
        assert(event.dao_uri == config.dao_uri.span(), 'dao_uri');
    }

    fn assert_factory_event_is_correct(
        factory_event: NewContractDeployed, space_address: ContractAddress
    ) {
        assert(factory_event.contract_address == space_address, 'space_contract_address');
        assert(
            factory_event.class_hash == Space::TEST_CLASS_HASH.try_into().unwrap(), 'class_hash'
        );
    }

    #[test]
    #[available_gas(10000000000)]
    fn deploy_test() {
        // Deploy Space 
        let config = setup();

        let (factory, space) = deploy(@config);

        let space_event = utils::pop_log::<SpaceCreated>(space.contract_address).unwrap();

        // Ensure the space emitted the proper event
        assert_space_event_is_correct(space_event, config, space.contract_address);

        let factory_event = utils::pop_log::<NewContractDeployed>(factory.contract_address)
            .unwrap();

        assert_factory_event_is_correct(factory_event, space.contract_address);
    }


    #[test]
    #[available_gas(10000000000)]
    fn deploy_reuse_salt() {
        let mut constructor_calldata = array![];

        let factory_address =
            match syscalls::deploy_syscall(
                Factory::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), false
            ) {
            Result::Ok((address, _)) => address,
            Result::Err(e) => {
                panic_with_felt252('deploy failed');
                starknet::contract_address_const::<0>()
            },
        };

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let contract_address_salt = 0;

        let config = setup();
        let constructor_calldata = config.get_initialize_calldata();

        let space_address = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
        let space_address_2 = factory
            .deploy(space_class_hash, contract_address_salt, constructor_calldata.span());
    // TODO: this test should fail but doesn't fail currently because of how the test environment works
    }
}
