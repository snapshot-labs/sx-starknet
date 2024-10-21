#[starknet::interface]
trait ISpaceV2<TContractState> {
    fn post_upgrade_initializer(ref self: TContractState, var: felt252);
    fn get_var(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod SpaceV2 {
    use super::ISpaceV2;
    use sx::utils::reinitializable::ReinitializableComponent;

    component!(
        path: ReinitializableComponent, storage: reinitializable, event: ReinitializableEvent
    );

    impl ReinitializableInternalImpl = ReinitializableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        _var: felt252,
        #[substorage(v0)]
        reinitializable: ReinitializableComponent::Storage,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        #[flat]
        ReinitializableEvent: ReinitializableComponent::Event
    }

    #[abi(embed_v0)]
    impl SpaceV2 of ISpaceV2<ContractState> {
        fn post_upgrade_initializer(ref self: ContractState, var: felt252) {
            self.reinitializable.initialize();
            self._var.write(var);
        }

        fn get_var(self: @ContractState) -> felt252 {
            self._var.read()
        }
    }
}
