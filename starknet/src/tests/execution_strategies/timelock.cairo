#[cfg(test)]
mod tests {
    use core::zeroable::Zeroable;
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

    use debug::PrintTrait;

    const RENOUNCE_OWNERSHIP_SELECTOR: felt252 =
        0x52580a92c73f4428f1a260c5d768ef462b25955307de00f99957df119865d;

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

        // Set timelock as space controller
        testing::set_caller_address(config.owner);
        testing::set_contract_address(config.owner);
        space.transfer_ownership(timelock.contract_address);
        (config, space, timelock, timelock_delay)
    }

    fn propose_and_vote(
        config: @Config,
        space: ISpaceDispatcher,
        timelock: ITimelockExecutionStrategyDispatcher,
        salt: felt252
    ) -> (u256, Array<felt252>) {
        // Create proposal
        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        // Call will renounce the timelocks ownership of the space
        let proposal_tx = CallWithSalt {
            to: space.contract_address,
            selector: RENOUNCE_OWNERSHIP_SELECTOR,
            calldata: array![],
            salt: salt
        };
        let mut payload = array![];
        array![proposal_tx].serialize(ref payload);

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

        // Pass voting delay period
        testing::set_block_timestamp(info::get_block_timestamp() + (*config.voting_delay).into());

        // Vote on proposal
        let mut vote_calldata = array![];
        let voter = UserAddress::Starknet(starknet::contract_address_const::<0x8765>());
        voter.serialize(ref vote_calldata);
        let proposal_id = space.next_proposal_id() - 1;
        proposal_id.serialize(ref vote_calldata);
        let choice = Choice::For(());
        choice.serialize(ref vote_calldata);
        let mut user_voting_strategies = array![IndexedStrategy { index: 0_u8, params: array![] }];
        user_voting_strategies.serialize(ref vote_calldata);
        let vote_metadata_uri: Array<felt252> = array![];
        vote_metadata_uri.serialize(ref vote_calldata);
        authenticator.authenticate(space.contract_address, VOTE_SELECTOR, vote_calldata);

        (proposal_id, payload)
    }

    #[test]
    #[available_gas(10000000000)]
    fn timelock_works() {
        let (config, space, timelock, timelock_delay) = setup_test();
        let (proposal_id, payload) = propose_and_vote(@config, space, timelock, 0);

        // Execute proposal on space, queueing it in the timelock
        space.execute(proposal_id, payload.clone());

        testing::set_block_timestamp(info::get_block_timestamp() + timelock_delay.into());
        // Execute proposal on timelock - should renounce ownership of space
        timelock.execute_queued_proposal(payload.span());
        assert(space.owner().is_zero(), 'renounce ownership failed');
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Unauthorized Space', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
    fn queue_from_unauthorized_space() {
        let (config, space, timelock, timelock_delay) = setup_test();

        let (proposal_id, payload) = propose_and_vote(@config, space, timelock, 0);

        testing::set_caller_address(timelock.owner());
        testing::set_contract_address(timelock.owner());
        timelock.disable_space(space.contract_address);
        assert(timelock.is_space_enabled(space.contract_address) == false, 'disable space failed');

        // Try to execute proposal on space, should fail because the space is disabled
        space.execute(proposal_id, payload.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Invalid Proposal Status', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
    fn proposal_didnt_pass() {
        let (config, space, timelock, timelock_delay) = setup_test();

        // Create proposal
        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0),
        };

        // Call will renounce the timelocks ownership of the space
        let proposal_tx = CallWithSalt {
            to: space.contract_address,
            selector: RENOUNCE_OWNERSHIP_SELECTOR,
            calldata: array![],
            salt: 0
        };
        let mut payload = array![];
        array![proposal_tx].serialize(ref payload);

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

        // No votes cast on proposal so quorum is not reached

        // Try to execute proposal on space, should fail because the proposal didn't pass
        space.execute(space.next_proposal_id() - 1, payload.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Already finalized', 'ENTRYPOINT_FAILED'))]
    fn queue_proposal_twice() {
        let (config, space, timelock, timelock_delay) = setup_test();
        let (proposal_id, payload) = propose_and_vote(@config, space, timelock, 0);

        // Execute proposal on space, queueing it in the timelock
        space.execute(proposal_id, payload.clone());

        // Try to execute proposal on space again, should fail because the proposal is already queued
        space.execute(proposal_id, payload.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Duplicate Hash', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
    fn queue_duplicate_proposal() {
        let (config, space, timelock, timelock_delay) = setup_test();
        // Creating and voting on 2 proposals with the same payload
        let (proposal_id_1, payload) = propose_and_vote(@config, space, timelock, 0);
        let (proposal_id_2, payload) = propose_and_vote(@config, space, timelock, 0);

        // Execute proposal on space, queueing it in the timelock
        space.execute(proposal_id_1, payload.clone());

        // Try to execute the second proposal, should fail because the payload is a duplicate
        space.execute(proposal_id_2, payload.clone());
    }

    #[test]
    #[available_gas(10000000000)]
    fn queue_duplicate_proposal_unique_salt() {
        let (config, space, timelock, timelock_delay) = setup_test();
        // Creating and voting on 2 proposals with the same payload
        let (proposal_id_1, payload_1) = propose_and_vote(@config, space, timelock, 0);
        let (proposal_id_2, payload_2) = propose_and_vote(@config, space, timelock, 1);

        // Execute proposal on space, queueing it in the timelock
        space.execute(proposal_id_1, payload_1.clone());

        // Execute the second proposal
        space.execute(proposal_id_2, payload_2.clone());
    }
}
