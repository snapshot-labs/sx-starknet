#[starknet::contract]
mod SessionKey {
    use starknet::{info, EthAddress};
    use sx::types::UserAddress;

    #[storage]
    struct Storage {
        // We use a general address type so we can handle EVM, Starknet, and other address types.
        _owner: LegacyMap::<felt252, UserAddress>,
        _end_timestamp: LegacyMap::<felt252, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SessionKeyRegistered: SessionKeyRegistered,
        SessionKeyRevoked: SessionKeyRevoked
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct SessionKeyRegistered {
        owner: UserAddress,
        session_public_key: felt252,
        end_timestamp: u32,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct SessionKeyRevoked {
        session_public_key: felt252,
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_valid_session_key(
            self: @ContractState, session_public_key: felt252, owner: UserAddress
        ) {
            // If the session key has been revoked, the owner will be the zero address.
            assert(self._owner.read(session_public_key) == owner, 'Invalid owner');

            let current_timestamp: u32 = info::get_block_timestamp().try_into().unwrap();
            let end_timestamp = self._end_timestamp.read(session_public_key);
            assert(current_timestamp < end_timestamp, 'Session key expired');
        }

        fn register(
            ref self: ContractState,
            owner: UserAddress,
            session_public_key: felt252,
            session_duration: u32
        ) {
            let current_timestamp = info::get_block_timestamp().try_into().unwrap();
            let end_timestamp = current_timestamp + session_duration; // Will revert on overflow
            self._owner.write(session_public_key, owner);
            self._end_timestamp.write(session_public_key, end_timestamp);

            self
                .emit(
                    Event::SessionKeyRegistered(
                        SessionKeyRegistered { owner, session_public_key, end_timestamp, }
                    )
                );
        }

        fn revoke(ref self: ContractState, owner: UserAddress, session_public_key: felt252) {
            assert(self._owner.read(session_public_key) == owner, 'Invalid owner');
            // Writing the zero address to the session key owner store
            self
                ._owner
                .write(
                    session_public_key,
                    UserAddress::Starknet(starknet::contract_address_const::<0>())
                );

            self.emit(Event::SessionKeyRevoked(SessionKeyRevoked { session_public_key }));
        }
    }
}

