#[cfg(test)]
mod tests {
    use starknet::syscalls;
    use sx::interfaces::{IQuorum, IQuorumDispatcher, IQuorumDispatcherTrait};
    use sx::tests::mocks::vanilla_execution_strategy::{VanillaExecutionStrategy};

    #[test]
    #[available_gas(10000000)]
    fn get_strategy_type() {
        let mut state: VanillaExecutionStrategy::ContractState =
            VanillaExecutionStrategy::unsafe_new_contract_state();

        let strategy_type = VanillaExecutionStrategy::VanillaExecutionStrategy::get_strategy_type(
            @state
        );

        assert(strategy_type == 'SimpleQuorumVanilla', 'invalid strategy type');
    }

    #[test]
    #[available_gas(10000000)]
    fn get_quorum() {
        let quorum = 42_u256;
        let mut constructor_calldata: Array<felt252> = array![];
        quorum.serialize(ref constructor_calldata);

        let (contract, _) = syscalls::deploy_syscall(
            VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false,
        )
            .unwrap();

        let strat = IQuorumDispatcher { contract_address: contract, };

        assert(strat.quorum() == quorum, 'invalid quorum');
    }
}
