#[starknet::interface]
trait ISpaceV2<TContractState> {
    fn initialize(ref self: TContractState, var: felt252);
    fn get_var(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod SpaceV2 {
    use super::ISpaceV2;
    use sx::utils::reinitializable::Reinitializable;
    use sx::utils::ReinitializableImpl;
    #[storage]
    struct Storage {
        _var: felt252
    }

    #[external(v0)]
    impl SpaceV2 of ISpaceV2<ContractState> {
        fn initialize(ref self: ContractState, var: felt252) {
            // TODO: Temp component syntax
            let mut state: Reinitializable::ContractState =
                Reinitializable::unsafe_new_contract_state();
            ReinitializableImpl::initialize(ref state);
            self._var.write(var);
        }
        fn get_var(self: @ContractState) -> felt252 {
            self._var.read()
        }
    }
}
