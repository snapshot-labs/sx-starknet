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
    use array::{ArrayTrait, SpanTrait};
    use serde::Serde;

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
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))]
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
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))]
    fn update_max_voting_duration_too_small() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.max_voting_duration = config.min_voting_duration - 1;

        space.update_settings(input.clone());
    // TODO: check event once it's been added
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
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid duration', 'ENTRYPOINT_FAILED'))]
    fn update_min_max_voting_duration_at_once_invalid() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.min_voting_duration = config.max_voting_duration + 1;
        input
            .max_voting_duration = config
            .max_voting_duration; // min is bigger than max, should fail

        space.update_settings(input.clone());
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn update_voting_delay() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.voting_delay = config.voting_delay + 1;

        space.update_settings(input.clone());

        assert(space.voting_delay() == input.voting_delay, 'Voting delay not updated');
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn metadata_uri() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        let mut arr = array![];
        'hello!'.serialize(ref arr);
        input.metadata_URI = arr;

        space.update_settings(input.clone());
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn dao_uri() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        input.dao_URI = array!['hello!'];

        space.update_settings(input.clone());
        assert(space.dao_uri() == input.dao_URI, 'dao uri not updated');
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn proposal_validation_strategy() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        let randomStrategy = StrategyImpl::from_address(
            contract_address_const::<'randomStrategy'>()
        );
        input.proposal_validation_strategy = randomStrategy;
        let mut arr = array![];
        'hello!'.serialize(ref arr);
        input.proposal_validation_strategy_metadata_URI = arr;

        space.update_settings(input.clone());

        assert(
            space.proposal_validation_strategy() == input.proposal_validation_strategy,
            'Proposal strategy not updated'
        );
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn add_authenticators() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        let auth1 = contract_address_const::<'authenticator1'>();
        let auth2 = contract_address_const::<'authenticator2'>();
        let mut arr = array![auth1, auth2];
        input.authenticators_to_add = arr;

        space.update_settings(input.clone());

        assert(space.authenticators(auth1) == true, 'Authenticator 1 not added');

        assert(space.authenticators(auth2) == true, 'Authenticator 2 not added');
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn remove_authenticators() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();
        let auth1 = *config.authenticators.at(0);
        let mut arr = array![auth1];
        input.authenticators_to_remove = arr;

        space.update_settings(input.clone());

        assert(space.authenticators(auth1) == false, 'Authenticator not removed');
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    fn add_voting_strategies() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();

        let vs1 = StrategyImpl::from_address(contract_address_const::<'votingStrategy1'>());
        let vs2 = StrategyImpl::from_address(contract_address_const::<'votingStrategy2'>());

        let mut arr = array![vs1.clone(), vs2.clone()];
        input.voting_strategies_to_add = arr;
        input.voting_strategies_metadata_URIs_to_add = array![array![], array![]];

        space.update_settings(input);

        assert(space.voting_strategies(1) == vs1, 'Voting strategy 1 not added');
        assert(space.voting_strategies(2) == vs2, 'Voting strategy 2 not added');
        assert(space.active_voting_strategies() == 0b111, 'Voting strategies not active');
    // TODO: check event once it's been added
    }


    #[test]
    #[available_gas(10000000000)]
    fn remove_voting_strategies() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();

        // First, add a new voting strategy
        let vs1 = StrategyImpl::from_address(contract_address_const::<'votingStrategy1'>());
        let mut arr = array![vs1.clone()];
        input.voting_strategies_to_add = arr;
        input.voting_strategies_metadata_URIs_to_add = array![array![]];
        space.update_settings(input);
        assert(space.voting_strategies(1) == vs1, 'Voting strategy 1 not added');
        assert(space.active_voting_strategies() == 0b11, 'Voting strategy not active');

        // Now, remove the first voting strategy
        let mut input = UpdateSettingsCalldataImpl::default();
        let mut arr = array![0];
        input.voting_strategies_to_remove = arr;

        space.update_settings(input);
        assert(space.active_voting_strategies() == 0b10, 'strategy not removed');
    // TODO: check event once it's been added
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('No active voting strategy left', 'ENTRYPOINT_FAILED'))]
    fn remove_all_voting_strategies() {
        let (config, space) = setup_update_settings();
        let mut input = UpdateSettingsCalldataImpl::default();

        // Remove the first voting strategy
        let mut arr = array![0];
        input.voting_strategies_to_remove = arr;

        space.update_settings(input);
    }
}
