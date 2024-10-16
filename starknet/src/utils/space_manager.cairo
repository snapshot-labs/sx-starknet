#[starknet::component]
mod SpaceManagerComponent {
    use starknet::{ContractAddress, info};

    #[storage]
    struct Storage {
        Spacemanager_spaces: LegacyMap::<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SpaceEnabled: SpaceEnabled,
        SpaceDisabled: SpaceDisabled
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct SpaceEnabled {
        space: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct SpaceDisabled {
        space: ContractAddress
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, mut spaces: Span<ContractAddress>
        ) {
            loop {
                match spaces.pop_front() {
                    Option::Some(space) => {
                        assert(
                            (*space).is_non_zero() && !self.Spacemanager_spaces.read(*space),
                            'Invalid Space'
                        );
                        self.Spacemanager_spaces.write(*space, true);
                    },
                    Option::None(()) => { break; }
                };
            }
        }

        fn enable_space(ref self: ComponentState<TContractState>, space: ContractAddress) {
            assert(space.is_non_zero() && !self.Spacemanager_spaces.read(space), 'Invalid Space');
            self.Spacemanager_spaces.write(space, true);
            self.emit(Event::SpaceEnabled(SpaceEnabled { space: space }));
        }

        fn disable_space(ref self: ComponentState<TContractState>, space: ContractAddress) {
            assert(self.Spacemanager_spaces.read(space), 'Invalid Space');
            self.Spacemanager_spaces.write(space, false);
            self.emit(Event::SpaceDisabled(SpaceDisabled { space: space }));
        }

        fn is_space_enabled(self: @ComponentState<TContractState>, space: ContractAddress) -> bool {
            return self.Spacemanager_spaces.read(space);
        }

        fn assert_only_spaces(self: @ComponentState<TContractState>) {
            assert(self.Spacemanager_spaces.read(info::get_caller_address()), 'Unauthorized Space');
        }
    }
}

#[cfg(test)]
mod tests {
    use starknet::{ContractAddress};
    use super::SpaceManagerComponent;
    use super::SpaceManagerComponent::InternalTrait;

    #[starknet::contract]
    mod MockContract {
        use super::SpaceManagerComponent;

        component!(path: SpaceManagerComponent, storage: space_manager, event: SpaceManagerEvent);

        #[storage]
        struct Storage {
            #[substorage(v0)]
            space_manager: SpaceManagerComponent::Storage
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            SpaceManagerEvent: SpaceManagerComponent::Event
        }

        impl SpaceManagerInternalImpl = SpaceManagerComponent::InternalImpl<ContractState>;
    }

    type ComponentState = SpaceManagerComponent::ComponentState<MockContract::ContractState>;

    fn COMPONENT_STATE() -> ComponentState {
        SpaceManagerComponent::component_state_for_testing()
    }

    #[test]
    #[available_gas(10000000)]
    fn initializer() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![starknet::contract_address_const::<0x123456789>()].span());
        assert(
            state.is_space_enabled(starknet::contract_address_const::<0x123456789>()),
            'initializer failed'
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn initializer_duplicate_address() {
        let mut state = COMPONENT_STATE();
        state
            .initializer(
                array![
                    starknet::contract_address_const::<0x123456789>(),
                    starknet::contract_address_const::<0x123456789>()
                ]
                    .span()
            );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn initializer_zero_address() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![starknet::contract_address_const::<0x0>()].span());
    }

    #[test]
    #[available_gas(10000000)]
    fn enable_space() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![].span());
        state.enable_space(starknet::contract_address_const::<0x123456789>());
        assert(
            state.is_space_enabled(starknet::contract_address_const::<0x123456789>()),
            'enable_space failed'
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn enable_space_duplicate_address() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![].span());
        state.enable_space(starknet::contract_address_const::<0x123456789>());
        state.enable_space(starknet::contract_address_const::<0x123456789>());
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn enable_space_zero_address() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![].span());
        state.enable_space(starknet::contract_address_const::<0x0>());
    }

    #[test]
    #[available_gas(10000000)]
    fn disable_space() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![starknet::contract_address_const::<0x123456789>()].span());
        state.disable_space(starknet::contract_address_const::<0x123456789>());
        assert(
            !state.is_space_enabled(starknet::contract_address_const::<0x123456789>()),
            'disable_space failed'
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn disable_space_not_enabled() {
        let mut state = COMPONENT_STATE();
        state.initializer(array![].span());
        state.disable_space(starknet::contract_address_const::<0x123456789>());
    }
}
