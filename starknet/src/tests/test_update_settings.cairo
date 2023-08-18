#[cfg(test)]
mod tests {
    use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::tests::setup::setup::setup::{setup, deploy, Config};
    use sx::types::{UpdateSettingsCalldata, UpdateSettingsCalldataImpl};
    use sx::tests::utils::strategy_trait::{StrategyImpl};
    use starknet::testing;
    use starknet::info;
    use starknet::contract_address_const;
    use clone::Clone;

    fn setup_update_settings() -> (Config, ISpaceDispatcher) {
        let config = setup();
        let (_, space) = deploy(@config);

        testing::set_caller_address(config.owner);
        testing::set_contract_address(config.owner);

        (config, space)
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
    fn update_unauthorized() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();

        testing::set_contract_address(contract_address_const::<'unauthorized'>());
        space.update_settings(input);
    }

    #[test]
    #[available_gas(10000000000)]
    fn update_min_voting_duration() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.min_voting_duration = config.min_voting_duration + 1;

        space.update_settings(input.clone());

        assert(
            space.min_voting_duration() == input.min_voting_duration,
            'Min voting duration not updated'
        );
    }

    #[test]
    #[available_gas(10000000000)]
    // #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))] // TODO: uncomment once PR is merged
    fn update_min_voting_duration_too_big() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.min_voting_duration = config.max_voting_duration + 1;

        space.update_settings(input.clone());
    }


    #[test]
    #[available_gas(10000000000)]
    fn update_max_voting_duration() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.max_voting_duration = config.max_voting_duration + 1;

        space.update_settings(input.clone());

        assert(
            space.max_voting_duration() == input.max_voting_duration,
            'Max voting duration not updated'
        );
    }

    #[test]
    #[available_gas(10000000000)]
    // #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))] // TODO: uncomment once PR is merged
    fn update_max_voting_duration_too_small() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.max_voting_duration = config.min_voting_duration - 1;

        space.update_settings(input.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    fn update_min_max_voting_duration_at_once() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.min_voting_duration = config.max_voting_duration + 1;
        input.max_voting_duration = config.max_voting_duration + 2;

        space.update_settings(input.clone());
        assert(
            space.min_voting_duration() == input.min_voting_duration,
            'Min voting duration not updated'
        );
        assert(
            space.max_voting_duration() == input.max_voting_duration,
            'Max voting duration not updated'
        );
    }

    #[test]
    #[available_gas(10000000000)]
    // #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))] // TODO: uncomment once PR is merged
    fn update_min_max_voting_duration_at_once_invalid() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.min_voting_duration = config.max_voting_duration + 1;
        input
            .max_voting_duration = config
            .max_voting_duration; // min is bigger than max, should fail

        space.update_settings(input.clone());
    }
}
