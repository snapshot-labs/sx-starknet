#[cfg(test)]
mod tests {
    use sx::execution_strategies::vanilla::{VanillaExecutionStrategy};

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
}
