#[cfg(test)]
mod tests {
    use sx::execution_strategies::timelock::ITimelockExecutionStrategyDispatcherTrait;
    use core::array::ArrayTrait;
    use core::serde::Serde;
    use starknet::{ContractAddress, syscalls, info, testing};
    // TODO: rexports    
    use sx::tests::setup::setup::{setup, setup::Config};
    use sx::interfaces::{IQuorum, IQuorumDispatcher, IQuorumDispatcherTrait};
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::execution_strategies::{
        TimelockExecutionStrategy, TimelockExecutionStrategy::CallWithSalt,
        timelock::ITimelockExecutionStrategyDispatcher
    };
    use sx::tests::mocks::vanilla_authenticator::{
        VanillaAuthenticator, IVanillaAuthenticatorDispatcher, IVanillaAuthenticatorDispatcherTrait
    };
    use sx::types::{
        UserAddress, Strategy, IndexedStrategy, Choice, FinalizationStatus, Proposal,
        UpdateSettingsCalldata
    };
    use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};

    fn setup_test() -> (Config, ISpaceDispatcher, ITimelockExecutionStrategyDispatcher, u32) {
        let mut config = setup::setup();
        config.min_voting_duration = 0;
        let (factory, space) = setup::deploy(@config);

        let spaces = array![space.contract_address];
        let timelock_delay = 100;
        let quorum = 1_u256;

        // Deploy Timelock execution strategy 
        let mut constructor_calldata = array![];
        config.owner.serialize(ref constructor_calldata);
        config.owner.serialize(ref constructor_calldata);
        spaces.serialize(ref constructor_calldata);
        timelock_delay.serialize(ref constructor_calldata);
        quorum.serialize(ref constructor_calldata);

        let (timelock_address, _) = syscalls::deploy_syscall(
            TimelockExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false
        )
            .unwrap();

        let timelock = ITimelockExecutionStrategyDispatcher { contract_address: timelock_address };

        (config, space, timelock, timelock_delay)
    }

    #[test]
    #[available_gas(10000000000)]
    fn timelock_works() {
        let (config, space, timelock, timelock_delay) = setup_test();

        // Create proposal
        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        let proposal_txs = array![
            CallWithSalt { to: config.owner, selector: 0x1234, calldata: array![], salt: 0 }
        ];
        let mut payload = array![];
        proposal_txs.serialize(ref payload);

        let timelock_execution_strategy = Strategy {
            address: timelock.contract_address, params: payload.clone()
        };

        let mut propose_calldata = array![];
        let author = UserAddress::Starknet(starknet::contract_address_const::<0x5678>());
        author.serialize(ref propose_calldata);
        let propose_metadata_uri: Array<felt252> = array![];
        propose_metadata_uri.serialize(ref propose_calldata);
        timelock_execution_strategy.serialize(ref propose_calldata);
        let user_proposal_validation_params: Array<felt252> = array![];
        user_proposal_validation_params.serialize(ref propose_calldata);
        authenticator.authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata);
        assert(space.next_proposal_id() == 2_u256, 'proposal failed');

        testing::set_block_timestamp(config.voting_delay.into());

        // Vote on proposal
        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(starknet::contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = 1_u256;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        let vote_metadata_uri: Array<felt252> = array![];
        vote_metadata_uri.serialize(ref vote_calldata);
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);

        // Execute proposal on space, queueing it in the timelock
        space.execute(proposal_id, payload.clone());

        testing::set_block_timestamp(info::get_block_timestamp() + timelock_delay.into());
    // Execute proposal on timelock
    // timelock.execute_queued_proposal(payload.span());

    // TODO: use a proper call - set timelock as space controller then update space param

    }
}
