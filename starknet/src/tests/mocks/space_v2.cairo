#[starknet::interface]
trait ISpaceV2<TContractState> {
    fn initialize(ref self: TContractState, var: felt252);
    fn get_var(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod SpaceV2 {
    use super::ISpaceV2;
    #[storage]
    struct Storage {
        _initialized: bool,
        _var: felt252
    }

    #[external(v0)]
    impl SpaceV2 of ISpaceV2<ContractState> {
        fn initialize(ref self: ContractState, var: felt252) {
            assert(self._initialized.read() == false, 'Contract already initialized');
            self._initialized.write(true);
            self._var.write(var);
        }
        fn get_var(self: @ContractState) -> felt252 {
            self._var.read()
        }
    }
}
