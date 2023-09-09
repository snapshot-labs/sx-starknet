/// EIP712 style typed data signing implementation.
/// See here for more info: https://community.starknet.io/t/snip-off-chain-signatures-a-la-eip712/98029
#[starknet::contract]
mod StarkEIP712 {
    use starknet::ContractAddress;
    use sx::types::{Strategy, IndexedStrategy, Choice};
    use sx::utils::StructHash;
    use sx::utils::constants::{
        STARKNET_MESSAGE, DOMAIN_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH,
        UPDATE_PROPOSAL_TYPEHASH, ERC165_ACCOUNT_INTERFACE_ID, ERC165_OLD_ACCOUNT_INTERFACE_ID
    };
    use sx::interfaces::{
        AccountABIDispatcher, AccountABIDispatcherTrait, AccountCamelABIDispatcher,
        AccountCamelABIDispatcherTrait
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
            signature: Array<felt252>,
            target: ContractAddress,
            author: ContractAddress,
            metadata_uri: Span<felt252>,
            execution_strategy: @Strategy,
            user_proposal_validation_params: Span<felt252>,
            salt: felt252,
            account_type: felt252,
        ) {
            let digest: felt252 = self
                .get_propose_digest(
                    target,
                    author,
                    metadata_uri,
                    execution_strategy,
                    user_proposal_validation_params,
                    salt
                );

            InternalImpl::verify_signature(digest, signature, author, account_type);
        }

        /// Verifies the signature of the vote calldata.
        fn verify_vote_sig(
            self: @ContractState,
            signature: Array<felt252>,
            target: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Span<IndexedStrategy>,
            metadata_uri: Span<felt252>,
            account_type: felt252,
        ) {
            let digest: felt252 = self
                .get_vote_digest(
                    target, voter, proposal_id, choice, user_voting_strategies, metadata_uri
                );
            InternalImpl::verify_signature(digest, signature, voter, account_type);
        }

        /// Verifies the signature of the update proposal calldata.
        fn verify_update_proposal_sig(
            self: @ContractState,
            signature: Array<felt252>,
            target: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: @Strategy,
            metadata_uri: Span<felt252>,
            salt: felt252,
            account_type: felt252,
        ) {
            let digest: felt252 = self
                .get_update_proposal_digest(
                    target, author, proposal_id, execution_strategy, metadata_uri, salt
                );
            InternalImpl::verify_signature(digest, signature, author, account_type);
        }

        /// Returns the digest of the propose calldata.
        fn get_propose_digest(
            self: @ContractState,
            space: ContractAddress,
            author: ContractAddress,
            metadata_uri: Span<felt252>,
            execution_strategy: @Strategy,
            user_proposal_validation_params: Span<felt252>,
            salt: felt252
        ) -> felt252 {
            let mut encoded_data = array![];
            PROPOSE_TYPEHASH.serialize(ref encoded_data);
            space.serialize(ref encoded_data);
            author.serialize(ref encoded_data);
            metadata_uri.struct_hash().serialize(ref encoded_data);
            execution_strategy.struct_hash().serialize(ref encoded_data);
            user_proposal_validation_params.struct_hash().serialize(ref encoded_data);
            salt.serialize(ref encoded_data);
            self.hash_typed_data(encoded_data.span().struct_hash(), author)
        }

        /// Returns the digest of the vote calldata.
        fn get_vote_digest(
            self: @ContractState,
            space: ContractAddress,
            voter: ContractAddress,
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
            self.hash_typed_data(encoded_data.span().struct_hash(), voter)
        }


        /// Returns the digest of the update proposal calldata.
        fn get_update_proposal_digest(
            self: @ContractState,
            space: ContractAddress,
            author: ContractAddress,
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
            self.hash_typed_data(encoded_data.span().struct_hash(), author)
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
        fn hash_typed_data(
            self: @ContractState, message_hash: felt252, signer: ContractAddress
        ) -> felt252 {
            let mut encoded_data = array![];
            STARKNET_MESSAGE.serialize(ref encoded_data);
            self._domain_hash.read().serialize(ref encoded_data);
            signer.serialize(ref encoded_data);
            message_hash.serialize(ref encoded_data);
            encoded_data.span().struct_hash()
        }

        /// Verifies the signature of a message by calling the account contract.
        fn verify_signature(
            digest: felt252,
            signature: Array<felt252>,
            account: ContractAddress,
            account_type: felt252
        ) {
            if account_type == 'snake' {
                assert(
                    AccountCamelABIDispatcher { contract_address: account }
                        .supportsInterface(ERC165_ACCOUNT_INTERFACE_ID) == true,
                    'Invalid Account'
                );
                AccountCamelABIDispatcher { contract_address: account }
                    .isValidSignature(digest, signature);
            } else if account_type == 'camel' {
                assert(
                    AccountABIDispatcher { contract_address: account }
                        .supports_interface(ERC165_OLD_ACCOUNT_INTERFACE_ID) == true,
                    'Invalid Account'
                );
                AccountABIDispatcher { contract_address: account }
                    .is_valid_signature(digest, signature);
            } else {
                panic_with_felt252('Invalid Account Type');
            }
        }
    }
}
