#[cfg(test)]
mod tests {
    use array::{ArrayTrait, SpanTrait};
    use starknet::{syscalls::deploy_syscall, testing, contract_address_const, };
    use traits::TryInto;
    use sx::factory::factory::{Factory, IFactoryDispatcher, IFactoryDispatcherTrait};
    use option::OptionTrait;
    use result::ResultTrait;
    use sx::space::space::Space;
    use sx::types::Strategy;
    use starknet::ClassHash;

    use sx::tests::setup::setup::setup::{setup, ConfigTrait, deploy};
    use openzeppelin::tests::utils;
    use openzeppelin::tests::utils::constants::ZERO;
    use sx::space::space::Space::SpaceCreated;
    use sx::factory::factory::Factory::NewContractDeployed;

    use traits::{PartialEq};
    use clone::Clone;

    #[test]
    #[available_gas(10000000000)]
    fn test_deploy() {
        // Deploy Space 
        let config = setup();

        let (factory, space) = deploy(@config);

        // Ensure the space emitted the proper event
        let space_event = utils::pop_log::<SpaceCreated>(space.contract_address).unwrap();
        assert(space_event.space == space.contract_address, 'space');
        assert(space_event.owner == config.owner, 'owner');
        assert(
            space_event.min_voting_duration == config.min_voting_duration, 'min_voting_duration'
        );
        assert(
            space_event.max_voting_duration == config.max_voting_duration, 'max_voting_duration'
        );
        assert(space_event.voting_delay == config.voting_delay, 'voting_delay');
        assert(
            space_event.proposal_validation_strategy == config.proposal_validation_strategy,
            'proposal_validation_strategy'
        );
        assert(
            space_event
                .proposal_validation_strategy_metadata_URI == config
                .proposal_validation_strategy_metadata_uri
                .span(),
            'prop_val_strat_metadata'
        );
        assert(
            space_event.voting_strategies == config.voting_strategies.span(), 'voting_strategies'
        );
        assert(
            space_event
                .voting_strategy_metadata_URIs == config
                .voting_strategies_metadata_uris
                .span(),
            'voting_strat_metadata'
        );
        assert(space_event.authenticators == config.authenticators.span(), 'authenticators');
        assert(space_event.metadata_URI == config.metadata_uri.span(), 'metadata_URI');
        assert(space_event.dao_URI == config.dao_uri.span(), 'dao_URI');

        let factory_event = utils::pop_log::<NewContractDeployed>(factory.contract_address)
            .unwrap();
        assert(factory_event.contract_address == space.contract_address, 'space_contract_address');
        assert(
            factory_event.class_hash == Space::TEST_CLASS_HASH.try_into().unwrap(), 'class_hash'
        );
    }


    #[test]
    #[available_gas(10000000000)]
    fn test_deploy_reuse_salt() {
        let mut constructor_calldata = array![];

        let (factory_address, _) = deploy_syscall(
            Factory::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), false
        )
            .unwrap();

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
