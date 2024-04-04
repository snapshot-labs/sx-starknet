/// EIP712 style typed data signing implementation for Session Key functions.
/// See here for more info: https://community.starknet.io/t/snip-off-chain-signatures-a-la-eip712/98029
#[starknet::contract]
mod StarkEIP712SessionKey {
    use starknet::{ContractAddress, EthAddress};
    use openzeppelin::account::interface::{AccountABIDispatcher, AccountABIDispatcherTrait};
    use sx::types::{Strategy, IndexedStrategy, Choice};
    use sx::utils::StructHash;
    use sx::utils::constants::{
        STARKNET_MESSAGE, DOMAIN_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH,
        UPDATE_PROPOSAL_TYPEHASH, ERC165_ACCOUNT_INTERFACE_ID
    };

    #[storage]
    struct Storage {
        _domain_hash: felt252
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name: felt252, version: felt252) {
            self._domain_hash.write(InternalImpl::get_domain_hash(name, version));
        }

        /// Verifies the signature of the propose calldata.
        fn verify_propose_sig(
            self: @ContractState,
            signature: Span<felt252>,
            space: ContractAddress,
            author: EthAddress,
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

            InternalImpl::is_valid_stark_signature(digest, session_public_key, signature);
        }

        /// Verifies the signature of the vote calldata.
        fn verify_vote_sig(
            self: @ContractState,
            signature: Span<felt252>,
            space: ContractAddress,
            voter: EthAddress,
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
            InternalImpl::is_valid_stark_signature(digest, session_public_key, signature);
        }

        /// Verifies the signature of the update proposal calldata.
        fn verify_update_proposal_sig(
            self: @ContractState,
            signature: Span<felt252>,
            space: ContractAddress,
            author: EthAddress,
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
            InternalImpl::is_valid_stark_signature(digest, session_public_key, signature);
        }

        /// Verifies the signature of a session key revokation.
        fn verify_session_key_revoke_sig(
            self: @ContractState,
            signature: Span<felt252>,
            salt: felt252,
            session_public_key: felt252
        ) {
            let digest: felt252 = self.get_session_key_revoke_digest(salt);
            InternalImpl::is_valid_stark_signature(digest, session_public_key, signature);
        }

        /// Returns the digest of the propose calldata.
        fn get_propose_digest(
            self: @ContractState,
            space: ContractAddress,
            author: EthAddress,
            metadata_uri: Span<felt252>,
            execution_strategy: @Strategy,
            user_proposal_validation_params: Span<felt252>,
            salt: felt252,
        ) -> felt252 {
            let mut encoded_data = array![];
            PROPOSE_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            author.serialize(ref encoded_data);
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
            voter: EthAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Span<IndexedStrategy>,
            metadata_uri: Span<felt252>,
        ) -> felt252 {
            let mut encoded_data = array![];
            VOTE_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            voter.serialize(ref encoded_data);
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
            author: EthAddress,
            proposal_id: u256,
            execution_strategy: @Strategy,
            metadata_uri: Span<felt252>,
            salt: felt252
        ) -> felt252 {
            let mut encoded_data = array![];
            UPDATE_PROPOSAL_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            author.serialize(ref encoded_data);
            proposal_id.struct_hash().serialize(ref encoded_data);
            execution_strategy.struct_hash().serialize(ref encoded_data);
            metadata_uri.struct_hash().serialize(ref encoded_data);
            salt.serialize(ref encoded_data);
            self.hash_typed_data(encoded_data.span().struct_hash())
        }

        fn get_session_key_revoke_digest(self: @ContractState, salt: felt252) -> felt252 {
            let mut encoded_data = array![];
            // TODO: Typehash
            // SESSION_KEY_REVOKE_TYPEHASH.serialize(ref encoded_data);
            salt.serialize(ref encoded_data);
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
            message_hash.serialize(ref encoded_data);
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
    }
}
