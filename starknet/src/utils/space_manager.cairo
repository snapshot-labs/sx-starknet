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
                        self._spaces.write(*space, true);
                    },
                    Option::None(()) => {
                        break;
                    }
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
