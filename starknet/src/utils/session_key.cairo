#[starknet::contract]
mod SessionKey {
    use starknet::{info, EthAddress};
    use sx::types::UserAddress;

    #[derive(Clone, Drop, Option, PartialEq, Serde, starknet::Store)]
    struct Session {
        // We use a general address type so we can handle EVM, Starknet, and other address types.
        owner: UserAddress,
        end_timestamp: u32,
    }

    #[storage]
    struct Storage {
        _sessions: LegacyMap::<felt252, Session>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SessionKeyRegistered: SessionKeyRegistered,
        SessionKeyRevoked: SessionKeyRevoked
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct SessionKeyRegistered {
        session_public_key: felt252,
        session: Session,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct SessionKeyRevoked {
        session_public_key: felt252,
        session: Session,
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // Reverts if a session key is invalid or the owner is not the address specified.
        fn assert_session_key_owner(
            self: @ContractState, session_public_key: felt252, owner: UserAddress
        ) {
            let session = self._sessions.read(session_public_key);
            self.assert_valid(@session);
            // If the session key has been revoked, the owner will be the zero address.
            assert(session.owner == owner, 'Invalid owner');
        }

        /// Returns the owner of the session key if it is valid.
        fn get_owner_if_valid(self: @ContractState, session_public_key: felt252) -> UserAddress {
            let session = self._sessions.read(session_public_key);
            self.assert_valid(@session);
            session.owner
        }

        /// Reverts if the session is invalid. 
        /// This occurs if the session does not exist (end timestamp is 0) or has expired.
        fn assert_valid(self: @ContractState, session: @Session) {
            let current_timestamp: u32 = info::get_block_timestamp().try_into().unwrap();
            assert(current_timestamp < *session.end_timestamp, 'Session key expired');
        }

        fn register(
            ref self: ContractState,
            owner: UserAddress,
            session_public_key: felt252,
            session_duration: u32
        ) {
            let current_timestamp = info::get_block_timestamp().try_into().unwrap();
            let end_timestamp = current_timestamp + session_duration; // Will revert on overflow
            let session = Session { owner, end_timestamp };

            self._sessions.write(session_public_key, session.clone());

            self
                .emit(
                    Event::SessionKeyRegistered(
                        SessionKeyRegistered { session_public_key, session }
                    )
                );
        }

        fn revoke(ref self: ContractState, session_public_key: felt252) {
            let session = self._sessions.read(session_public_key);
            self.assert_valid(@session);

            // Writing the session state to zero.
            self
                ._sessions
                .write(
                    session_public_key,
                    Session {
                        owner: UserAddress::Starknet(starknet::contract_address_const::<0>()),
                        end_timestamp: 0
                    }
                );

            self.emit(Event::SessionKeyRevoked(SessionKeyRevoked { session_public_key, session }));
        }
    }
}

