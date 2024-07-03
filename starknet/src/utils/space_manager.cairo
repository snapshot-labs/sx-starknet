#[starknet::contract]
mod SpaceManager {
    use starknet::{ContractAddress, info};

    #[storage]
    struct Storage {
        _spaces: LegacyMap::<ContractAddress, bool>
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
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, mut spaces: Span<ContractAddress>) {
            loop {
                match spaces.pop_front() {
                    Option::Some(space) => {
                        assert(
                            (*space).is_non_zero() && !self._spaces.read(*space), 'Invalid Space'
                        );
                        self._spaces.write(*space, true);
                    },
                    Option::None(()) => { break; }
                };
            }
        }

        fn enable_space(ref self: ContractState, space: ContractAddress) {
            assert(space.is_non_zero() && !self._spaces.read(space), 'Invalid Space');
            self._spaces.write(space, true);
            self.emit(Event::SpaceEnabled(SpaceEnabled { space: space }));
        }

        fn disable_space(ref self: ContractState, space: ContractAddress) {
            assert(self._spaces.read(space), 'Invalid Space');
            self._spaces.write(space, false);
            self.emit(Event::SpaceDisabled(SpaceDisabled { space: space }));
        }

        fn is_space_enabled(self: @ContractState, space: ContractAddress) -> bool {
            return self._spaces.read(space);
        }

        fn assert_only_spaces(self: @ContractState) {
            assert(self._spaces.read(info::get_caller_address()), 'Unauthorized Space');
        }
    }
}

#[cfg(test)]
mod tests {
    use starknet::{ContractAddress};
    use super::SpaceManager;

    #[test]
    #[available_gas(10000000)]
    fn initializer() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(
            ref state, array![starknet::contract_address_const::<0x123456789>()].span()
        );
        assert(
            SpaceManager::InternalImpl::is_space_enabled(
                @state, starknet::contract_address_const::<0x123456789>()
            ),
            'initializer failed'
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn initializer_duplicate_address() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(
            ref state,
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
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(
            ref state, array![starknet::contract_address_const::<0x0>()].span()
        );
    }

    #[test]
    #[available_gas(10000000)]
    fn enable_space() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(ref state, array![].span());
        SpaceManager::InternalImpl::enable_space(
            ref state, starknet::contract_address_const::<0x123456789>()
        );
        assert(
            SpaceManager::InternalImpl::is_space_enabled(
                @state, starknet::contract_address_const::<0x123456789>()
            ),
            'enable_space failed'
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn enable_space_duplicate_address() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(ref state, array![].span());
        SpaceManager::InternalImpl::enable_space(
            ref state, starknet::contract_address_const::<0x123456789>()
        );
        SpaceManager::InternalImpl::enable_space(
            ref state, starknet::contract_address_const::<0x123456789>()
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn enable_space_zero_address() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(ref state, array![].span());
        SpaceManager::InternalImpl::enable_space(
            ref state, starknet::contract_address_const::<0x0>()
        );
    }

    #[test]
    #[available_gas(10000000)]
    fn disable_space() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(
            ref state, array![starknet::contract_address_const::<0x123456789>()].span()
        );
        SpaceManager::InternalImpl::disable_space(
            ref state, starknet::contract_address_const::<0x123456789>()
        );
        assert(
            !SpaceManager::InternalImpl::is_space_enabled(
                @state, starknet::contract_address_const::<0x123456789>()
            ),
            'disable_space failed'
        );
    }

    #[test]
    #[available_gas(10000000)]
    #[should_panic(expected: ('Invalid Space',))]
    fn disable_space_not_enabled() {
        let mut state = SpaceManager::unsafe_new_contract_state();
        SpaceManager::InternalImpl::initializer(ref state, array![].span());
        SpaceManager::InternalImpl::disable_space(
            ref state, starknet::contract_address_const::<0x123456789>()
        );
    }
}
