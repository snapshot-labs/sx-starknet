#[starknet::contract]
mod SessionKey {
    // use core::debug::PrintTrait;
    use starknet::{info, ContractAddress, EthAddress};
    use sx::types::{
        Strategy, IndexedStrategy, Choice, UserAddress, UserAddressTrait, UserAddressIntoFelt
    };
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::{
        EIP712, StarkEIP712, StructHash, LegacyHashEthAddress, LegacyHashUserAddressU256,
        LegacyHashFelt252EthAddress,
    };
    use sx::utils::constants::{
        STARKNET_MESSAGE, DOMAIN_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH,
        UPDATE_PROPOSAL_TYPEHASH, SESSION_KEY_REVOKE_TYPEHASH, ERC165_ACCOUNT_INTERFACE_ID,
        REGISTER_SESSION_WITH_OWNER_TX_SELECTOR, REVOKE_SESSION_WITH_OWNER_TX_SELECTOR
    };

    #[derive(Clone, Drop, Option, PartialEq, Serde, starknet::Store)]
    struct Session {
        // We use a general address type so we can handle EVM, Starknet, and other address types.
        owner: UserAddress,
        end_timestamp: u32,
    }

    #[storage]
    struct Storage {
        _domain_hash: felt252,
        _used_salts: LegacyMap::<(UserAddress, u256), bool>,
        _sessions: LegacyMap::<felt252, Session>,
        _starknet_commit_address: EthAddress,
        _commits: LegacyMap::<(felt252, EthAddress), bool>
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
        fn authenticate_propose(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            author: UserAddress,
            metadata_uri: Array<felt252>,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
            session_public_key: felt252
        ) {
            self.assert_session_key_owner(session_public_key, author);

            assert(!self._used_salts.read((author, salt.into())), 'Salt Already Used');

            self
                .verify_propose_sig(
                    signature.span(),
                    space,
                    author,
                    metadata_uri.span(),
                    @execution_strategy,
                    user_proposal_validation_params.span(),
                    salt,
                    session_public_key
                );

            self._used_salts.write((author, salt.into()), true);

            ISpaceDispatcher { contract_address: space }
                .propose(
                    author, metadata_uri, execution_strategy, user_proposal_validation_params,
                );
        }

        fn authenticate_vote(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            voter: UserAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_uri: Array<felt252>,
            session_public_key: felt252
        ) {
            // No need to check salts here, as double voting is prevented by the space itself.

            self.assert_session_key_owner(session_public_key, voter);

            self
                .verify_vote_sig(
                    signature.span(),
                    space,
                    voter,
                    proposal_id,
                    choice,
                    user_voting_strategies.span(),
                    metadata_uri.span(),
                    session_public_key
                );

            ISpaceDispatcher { contract_address: space }
                .vote(voter, proposal_id, choice, user_voting_strategies, metadata_uri);
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            author: UserAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_uri: Array<felt252>,
            salt: felt252,
            session_public_key: felt252
        ) {
            assert(!self._used_salts.read((author, salt.into())), 'Salt Already Used');

            self.assert_session_key_owner(session_public_key, author);

            self
                .verify_update_proposal_sig(
                    signature.span(),
                    space,
                    author,
                    proposal_id,
                    @execution_strategy,
                    metadata_uri.span(),
                    salt,
                    session_public_key
                );

            self._used_salts.write((author, salt.into()), true);

            ISpaceDispatcher { contract_address: space }
                .update_proposal(author, proposal_id, execution_strategy, metadata_uri);
        }

        fn register_with_owner_eth_sig(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            owner: EthAddress,
            session_public_key: felt252,
            session_duration: u32,
            salt: u256,
        ) {
            assert(
                !self._used_salts.read((UserAddress::Ethereum(owner), salt)), 'Salt Already Used'
            );

            let state = EIP712::unsafe_new_contract_state();
            EIP712::InternalImpl::verify_session_key_auth_sig(
                @state, r, s, v, owner, session_public_key, session_duration, salt
            );

            self._used_salts.write((UserAddress::Ethereum(owner), salt), true);

            self.register(UserAddress::Ethereum(owner), session_public_key, session_duration);
        }

        fn revoke_with_owner_eth_sig(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            owner: EthAddress,
            session_public_key: felt252,
            salt: u256,
        ) {
            self.assert_session_key_owner(session_public_key, UserAddress::Ethereum(owner));
            assert(
                !self._used_salts.read((UserAddress::Ethereum(owner), salt)), 'Salt Already Used'
            );

            let state = EIP712::unsafe_new_contract_state();
            EIP712::InternalImpl::verify_session_key_revoke_sig(
                @state, r, s, v, owner, session_public_key, salt
            );

            self._used_salts.write((UserAddress::Ethereum(owner), salt), true);

            self.revoke(session_public_key);
        }

        fn register_with_owner_eth_tx(
            ref self: ContractState,
            owner: EthAddress,
            session_public_key: felt252,
            session_duration: u32,
        ) {
            let mut payload = array![];
            starknet::get_contract_address().serialize(ref payload);
            REGISTER_SESSION_WITH_OWNER_TX_SELECTOR.serialize(ref payload);
            owner.serialize(ref payload);
            session_public_key.serialize(ref payload);
            session_duration.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            self.consume_commit(payload_hash, owner);

            self.register(UserAddress::Ethereum(owner), session_public_key, session_duration);
        }

        fn revoke_with_owner_eth_tx(
            ref self: ContractState, owner: EthAddress, session_public_key: felt252
        ) {
            let mut payload = array![];
            starknet::get_contract_address().serialize(ref payload);
            REVOKE_SESSION_WITH_OWNER_TX_SELECTOR.serialize(ref payload);
            owner.serialize(ref payload);
            session_public_key.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            self.consume_commit(payload_hash, owner);

            self.revoke(session_public_key);
        }

        fn register_with_owner_stark_sig(
            ref self: ContractState,
            signature: Array<felt252>,
            owner: ContractAddress,
            session_public_key: felt252,
            session_duration: u32,
            salt: felt252,
        ) {
            assert(
                !self._used_salts.read((UserAddress::Starknet(owner), salt.into())),
                'Salt Already Used'
            );

            let state = StarkEIP712::unsafe_new_contract_state();
            StarkEIP712::InternalImpl::verify_session_key_auth_sig(
                @state, signature, owner, session_public_key, session_duration, salt
            );

            self._used_salts.write((UserAddress::Starknet(owner), salt.into()), true);

            self.register(UserAddress::Starknet(owner), session_public_key, session_duration);
        }

        fn revoke_with_owner_stark_sig(
            ref self: ContractState,
            signature: Array<felt252>,
            owner: ContractAddress,
            session_public_key: felt252,
            salt: felt252,
        ) {
            self.assert_session_key_owner(session_public_key, UserAddress::Starknet(owner));
            assert(
                !self._used_salts.read((UserAddress::Starknet(owner), salt.into())),
                'Salt Already Used'
            );

            let state = StarkEIP712::unsafe_new_contract_state();
            StarkEIP712::InternalImpl::verify_session_key_revoke_sig(
                @state, signature, owner, session_public_key, salt
            );

            self._used_salts.write((UserAddress::Starknet(owner), salt.into()), true);

            self.revoke(session_public_key);
        }

        fn register_with_owner_stark_tx(
            ref self: ContractState,
            owner: ContractAddress,
            session_public_key: felt252,
            session_duration: u32,
        ) {
            assert(info::get_caller_address() == owner, 'Invalid Caller');

            self.register(UserAddress::Starknet(owner), session_public_key, session_duration);
        }

        fn revoke_with_owner_stark_tx(
            ref self: ContractState, owner: ContractAddress, session_public_key: felt252
        ) {
            assert(info::get_caller_address() == owner, 'Invalid Caller');

            self.revoke(session_public_key);
        }

        fn revoke_with_session_key_sig(
            ref self: ContractState,
            signature: Array<felt252>,
            owner: UserAddress,
            session_public_key: felt252,
            salt: felt252,
        ) {
            self.assert_session_key_owner(session_public_key, owner);
            assert(!self._used_salts.read((owner, salt.into())), 'Salt Already Used');

            self.verify_session_key_revoke_sig(signature.span(), owner, session_public_key, salt);

            self._used_salts.write((owner, salt.into()), true);

            self.revoke(session_public_key);
        }


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

        fn eth_sig_initializer(ref self: ContractState, name: felt252, version: felt252) {
            self._domain_hash.write(InternalImpl::get_domain_hash(name, version));
        }

        fn eth_tx_initializer(
            ref self: ContractState,
            name: felt252,
            version: felt252,
            starknet_commit_address: EthAddress
        ) {
            self._domain_hash.write(InternalImpl::get_domain_hash(name, version));
            self._starknet_commit_address.write(starknet_commit_address);
        }

        /// Verifies the signature of the propose calldata.
        fn verify_propose_sig(
            self: @ContractState,
            signature: Span<felt252>,
            space: ContractAddress,
            author: UserAddress,
            metadata_uri: Span<felt252>,
            execution_strategy: @Strategy,
            user_proposal_validation_params: Span<felt252>,
            salt: felt252,
            session_public_key: felt252
        ) {
            let digest: felt252 = self
                .get_propose_digest(
                    space,
                    author,
                    metadata_uri,
                    execution_strategy,
                    user_proposal_validation_params,
                    salt
                );

            assert(
                InternalImpl::is_valid_stark_signature(digest, session_public_key, signature),
                'Invalid Signature'
            );
        }

        /// Verifies the signature of the vote calldata.
        fn verify_vote_sig(
            self: @ContractState,
            signature: Span<felt252>,
            space: ContractAddress,
            voter: UserAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Span<IndexedStrategy>,
            metadata_uri: Span<felt252>,
            session_public_key: felt252
        ) {
            let digest: felt252 = self
                .get_vote_digest(
                    space, voter, proposal_id, choice, user_voting_strategies, metadata_uri
                );
            assert(
                InternalImpl::is_valid_stark_signature(digest, session_public_key, signature),
                'Invalid Signature'
            );
        }

        /// Verifies the signature of the update proposal calldata.
        fn verify_update_proposal_sig(
            self: @ContractState,
            signature: Span<felt252>,
            space: ContractAddress,
            author: UserAddress,
            proposal_id: u256,
            execution_strategy: @Strategy,
            metadata_uri: Span<felt252>,
            salt: felt252,
            session_public_key: felt252
        ) {
            let digest: felt252 = self
                .get_update_proposal_digest(
                    space, author, proposal_id, execution_strategy, metadata_uri, salt
                );
            assert(
                InternalImpl::is_valid_stark_signature(digest, session_public_key, signature),
                'Invalid Signature'
            );
        }

        /// Verifies the signature of a session key revokation.
        fn verify_session_key_revoke_sig(
            self: @ContractState,
            signature: Span<felt252>,
            owner: UserAddress,
            session_public_key: felt252,
            salt: felt252,
        ) {
            let digest: felt252 = self
                .get_session_key_revoke_digest(owner, session_public_key, salt);
            assert(
                InternalImpl::is_valid_stark_signature(digest, session_public_key, signature),
                'Invalid Signature'
            );
        }

        /// Returns the digest of the propose calldata.
        fn get_propose_digest(
            self: @ContractState,
            space: ContractAddress,
            author: UserAddress,
            metadata_uri: Span<felt252>,
            execution_strategy: @Strategy,
            user_proposal_validation_params: Span<felt252>,
            salt: felt252,
        ) -> felt252 {
            let mut encoded_data = array![];
            PROPOSE_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            UserAddressIntoFelt::into(author).serialize(ref encoded_data);
            metadata_uri.struct_hash().serialize(ref encoded_data);
            execution_strategy.struct_hash().serialize(ref encoded_data);
            user_proposal_validation_params.struct_hash().serialize(ref encoded_data);
            salt.serialize(ref encoded_data);
            self.hash_typed_data(encoded_data.span().struct_hash())
        }

        /// Returns the digest of the vote calldata.
        fn get_vote_digest(
            self: @ContractState,
            space: ContractAddress,
            voter: UserAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Span<IndexedStrategy>,
            metadata_uri: Span<felt252>,
        ) -> felt252 {
            let mut encoded_data = array![];
            VOTE_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            UserAddressIntoFelt::into(voter).serialize(ref encoded_data);
            proposal_id.struct_hash().serialize(ref encoded_data);
            choice.serialize(ref encoded_data);
            user_voting_strategies.struct_hash().serialize(ref encoded_data);
            metadata_uri.struct_hash().serialize(ref encoded_data);
            self.hash_typed_data(encoded_data.span().struct_hash())
        }


        /// Returns the digest of the update proposal calldata.
        fn get_update_proposal_digest(
            self: @ContractState,
            space: ContractAddress,
            author: UserAddress,
            proposal_id: u256,
            execution_strategy: @Strategy,
            metadata_uri: Span<felt252>,
            salt: felt252
        ) -> felt252 {
            let mut encoded_data = array![];
            UPDATE_PROPOSAL_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            UserAddressIntoFelt::into(author).serialize(ref encoded_data);
            proposal_id.struct_hash().serialize(ref encoded_data);
            execution_strategy.struct_hash().serialize(ref encoded_data);
            metadata_uri.struct_hash().serialize(ref encoded_data);
            salt.serialize(ref encoded_data);
            self.hash_typed_data(encoded_data.span().struct_hash())
        }

        fn get_session_key_revoke_digest(
            self: @ContractState, owner: UserAddress, session_public_key: felt252, salt: felt252
        ) -> felt252 {
            let mut encoded_data = array![];
            SESSION_KEY_REVOKE_TYPEHASH.serialize(ref encoded_data);
            UserAddressIntoFelt::into(owner).serialize(ref encoded_data);
            session_public_key.serialize(ref encoded_data);
            salt.serialize(ref encoded_data);
            // encoded_data.clone().print();
            self.hash_typed_data(encoded_data.span().struct_hash())
        }

        /// Returns the domain hash of the contract.
        fn get_domain_hash(name: felt252, version: felt252) -> felt252 {
            let mut encoded_data = array![];
            DOMAIN_TYPEHASH.serialize(ref encoded_data);
            name.serialize(ref encoded_data);
            version.serialize(ref encoded_data);
            starknet::get_tx_info().unbox().chain_id.serialize(ref encoded_data);
            starknet::get_contract_address().serialize(ref encoded_data);
            encoded_data.span().struct_hash()
        }

        /// Hashes typed data according to the starknet equiavalent to the EIP-712 specification.
        fn hash_typed_data(self: @ContractState, message_hash: felt252) -> felt252 {
            let mut encoded_data = array![];
            STARKNET_MESSAGE.serialize(ref encoded_data);
            self._domain_hash.read().serialize(ref encoded_data);
            0x1.serialize(ref encoded_data);
            message_hash.serialize(ref encoded_data);
            // encoded_data.clone().print();
            encoded_data.span().struct_hash()
        }

        /// OpenZeppelin Implementation
        /// NOTE: Did not import as our OZ dependency is not the latest version.
        fn is_valid_stark_signature(
            msg_hash: felt252, public_key: felt252, signature: Span<felt252>
        ) -> bool {
            let valid_length = signature.len() == 2;

            if valid_length {
                ecdsa::check_ecdsa_signature(
                    msg_hash, public_key, *signature.at(0_u32), *signature.at(1_u32)
                )
            } else {
                false
            }
        }

        fn consume_commit(ref self: ContractState, hash: felt252, sender_address: EthAddress) {
            assert(self._commits.read((hash, sender_address)), 'Commit not found');
            // Delete the commit to prevent replay attacks.
            self._commits.write((hash, sender_address), false);
        }

        fn commit(
            ref self: ContractState, from_address: felt252, sender_address: felt252, hash: felt252
        ) {
            assert(
                from_address == self._starknet_commit_address.read().into(),
                'Invalid commit address'
            );
            let sender_address = sender_address.try_into().unwrap();
            assert(self._commits.read((hash, sender_address)) == false, 'Commit already exists');
            self._commits.write((hash, sender_address), true);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::SessionKey;
    use debug::PrintTrait;

    use starknet::{info, ContractAddress, EthAddress};
    use sx::types::{Strategy, IndexedStrategy, Choice, UserAddress, UserAddressTrait};
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::{
        EIP712, StarkEIP712, StructHash, LegacyHashEthAddress, LegacyHashUserAddressU256,
        LegacyHashFelt252EthAddress
    };
    use sx::utils::constants::{
        STARKNET_MESSAGE, DOMAIN_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH,
        UPDATE_PROPOSAL_TYPEHASH, ERC165_ACCOUNT_INTERFACE_ID,
        REGISTER_SESSION_WITH_OWNER_TX_SELECTOR, REVOKE_SESSION_WITH_OWNER_TX_SELECTOR
    };

    #[test]
    #[available_gas(10000000)]
    fn testSessionKey() {
        let state = SessionKey::unsafe_new_contract_state();
        let mut payload = array![];
        starknet::get_contract_address().serialize(ref payload);
        REGISTER_SESSION_WITH_OWNER_TX_SELECTOR.serialize(ref payload);
        0x1234.serialize(ref payload);
        0x5678.serialize(ref payload);
        0x9999.serialize(ref payload);
        payload.print();
    }
}

