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

    fn assert_space_event_is_correct(config: Config, space_address: ContractAddress) {
        let event = utils::pop_log::<Space::Event>(space_address).unwrap();
        let expected = Space::Event::SpaceCreated(
            SpaceCreated {
                space: space_address,
                owner: config.owner,
                min_voting_duration: config.min_voting_duration,
                max_voting_duration: config.max_voting_duration,
                voting_delay: config.voting_delay,
                proposal_validation_strategy: config.proposal_validation_strategy,
                proposal_validation_strategy_metadata_uri: config
                    .proposal_validation_strategy_metadata_uri
                    .span(),
                voting_strategies: config.voting_strategies.span(),
                voting_strategy_metadata_uris: config.voting_strategies_metadata_uris.span(),
                authenticators: config.authenticators.span(),
                metadata_uri: config.metadata_uri.span(),
                dao_uri: config.dao_uri.span(),
            }
        );

        assert(event == expected, 'SpaceCreated event incorrect');
    }

    fn assert_factory_event_is_correct(
        factory_address: ContractAddress, space_address: ContractAddress
    ) {
        let factory_event = utils::pop_log::<Factory::Event>(factory_address).unwrap();

        let expected = Factory::Event::NewContractDeployed(
            NewContractDeployed {
                contract_address: space_address,
                class_hash: Space::TEST_CLASS_HASH.try_into().unwrap(),
            }
        );

        assert(factory_event == expected, 'Factory event incorrect');
    }

    #[test]
    #[available_gas(10000000000)]
    fn deploy_test() {
        // Deploy Space 
        let config = setup();

        let (factory, space) = deploy(@config);

        // Ensure the space emitted the proper event
        assert_space_event_is_correct(config, space.contract_address);

        // Ensure the facotry emitted the proper event
        assert_factory_event_is_correct(factory.contract_address, space.contract_address);
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
            Result::Err(_) => {
                panic_with_felt252('deploy failed');
                starknet::contract_address_const::<0>()
            },
        };

        let factory = IFactoryDispatcher { contract_address: factory_address };

        let space_class_hash: ClassHash = Space::TEST_CLASS_HASH.try_into().unwrap();
        let salt_nonce = 0;

        let config = setup();
        let constructor_calldata = config.get_initialize_calldata();

        let _ = factory.deploy(space_class_hash, constructor_calldata.span(), salt_nonce);
        let _ = factory.deploy(space_class_hash, constructor_calldata.span(), salt_nonce);
    // TODO: this test should fail but doesn't fail currently because of how the test environment works
    }
}
