use sx::interfaces::i_proposal_validation_strategy::IProposalValidationStrategyDispatcherTrait;
#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use starknet::{
        class_hash::Felt252TryIntoClassHash, ContractAddress, syscalls::deploy_syscall, testing,
        contract_address_const, info
    };
    use traits::{Into, TryInto};
    use result::ResultTrait;
    use option::OptionTrait;
    use integer::u256_from_felt252;
    use clone::Clone;
    use serde::{Serde};

    use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::authenticators::vanilla::{
        VanillaAuthenticator, IVanillaAuthenticatorDispatcher, IVanillaAuthenticatorDispatcherTrait
    };
    use sx::execution_strategies::vanilla::VanillaExecutionStrategy;
    use sx::voting_strategies::vanilla::VanillaVotingStrategy;
    use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
    use sx::tests::mocks::proposal_validation_always_fail::AlwaysFailProposalValidationStrategy;
    use sx::types::{
        UserAddress, Strategy, IndexedStrategy, Choice, FinalizationStatus, Proposal,
        UpdateSettingsCalldataImpl
    };
    use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};
    use sx::tests::setup::setup::setup::{setup, deploy};
    use sx::interfaces::{
        IProposalValidationStrategyDispatcher, IProposalValidationStrategyDispatcherTrait
    };
    use sx::tests::mocks::executor::{
        ExecutorExecutionStrategy, ExecutorExecutionStrategy::Transaction
    };
    use starknet::ClassHash;

    use Space::Space as SpaceImpl;

    #[test]
    #[available_gas(10000000000)]
    fn test_upgrade() {
        let config = setup();
        let (factory, space) = deploy(@config);

        // New implementation is not a proposer space but a random contract (here, a proposal validation strategy).
        let new_implem = AlwaysFailProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap();

        testing::set_contract_address(config.owner);

        // Now upgrade the implementation
        space.upgrade(new_implem);

        // Ensure it works
        let new_space = IProposalValidationStrategyDispatcher {
            contract_address: space.contract_address
        };

        let author = UserAddress::Starknet(contract_address_const::<0x7777777777>());
        let params = ArrayTrait::<felt252>::new();
        let user_params = ArrayTrait::<felt252>::new();
        let res = new_space.validate(author, params, user_params);
        assert(res == false, 'Strategy did not return false');
    }

    #[test]
    #[available_gas(10000000000)]
    fn test_upgrade_via_execution_strategy() {
        let config = setup();
        let (factory, space) = deploy(@config);
        let proposal_id = space.next_proposal_id();

        // New implementation is not a proposer space but a random contract (here, a proposal validation strategy).
        let new_implem: ClassHash = AlwaysFailProposalValidationStrategy::TEST_CLASS_HASH
            .try_into()
            .unwrap();

        let (execution_contract_address, _) = deploy_syscall(
            ExecutorExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            ArrayTrait::<felt252>::new().span(),
            false
        )
            .unwrap();

        // Set the owner to be the execution strategy
        testing::set_contract_address(config.owner);
        space.transfer_ownership(execution_contract_address);

        // keccak256("upgrade") & (2**250 - 1)
        let selector = 0xf2f7c15cbe06c8d94597cd91fd7f3369eae842359235712def5584f8d270cd;
        let mut tx_calldata = ArrayTrait::new();
        new_implem.serialize(ref tx_calldata);
        let tx = Transaction { target: space.contract_address, selector, data: tx_calldata,  };

        let mut execution_params = ArrayTrait::<felt252>::new();
        tx.serialize(ref execution_params);

        let execution_strategy = Strategy {
            address: execution_contract_address, params: execution_params.clone(), 
        };

        let mut propose_calldata = ArrayTrait::<felt252>::new();
        UserAddress::Starknet(contract_address_const::<0x7676>()).serialize(ref propose_calldata);
        execution_strategy.serialize(ref propose_calldata);
        ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

        let authenticator = IVanillaAuthenticatorDispatcher {
            contract_address: *config.authenticators.at(0)
        };
        authenticator
            .authenticate(space.contract_address, PROPOSE_SELECTOR, propose_calldata.clone());

        // Now upgrade the implementation
        space.execute(proposal_id, execution_params);

        // Ensure it works
        let new_space = IProposalValidationStrategyDispatcher {
            contract_address: space.contract_address
        };

        let author = UserAddress::Starknet(contract_address_const::<0x7777777777>());
        let params = ArrayTrait::<felt252>::new();
        let user_params = ArrayTrait::<felt252>::new();
        let res = new_space.validate(author, params, user_params);
        assert(res == false, 'Strategy did not return false');
    }
}
