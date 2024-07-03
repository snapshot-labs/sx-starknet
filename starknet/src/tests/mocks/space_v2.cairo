#[starknet::interface]
trait ISpaceV2<TContractState> {
    fn post_upgrade_initializer(ref self: TContractState, var: felt252);
    fn get_var(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod SpaceV2 {
    use super::ISpaceV2;
    use sx::utils::reinitializable::Reinitializable;

    #[storage]
    struct Storage {
        _var: felt252
    }

    #[abi(embed_v0)]
    impl SpaceV2 of ISpaceV2<ContractState> {
        fn post_upgrade_initializer(ref self: ContractState, var: felt252) {
            // Migration to components planned ; disregard the `unsafe` keyword,
            // it is actually safe.
            let mut state = Reinitializable::unsafe_new_contract_state();
            Reinitializable::InternalImpl::initialize(ref state);
            self._var.write(var);
        }

        fn get_var(self: @ContractState) -> felt252 {
            self._var.read()
        }
    }
}
