use starknet::ContractAddress;
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IStarkSigAuthenticator<TContractState> {
    /// Authenticates a propose transaction using the starknet EIP712-equivalent signature scheme.
    /// Note: Only SNIP-6 compliant accounts are supported.
    /// 
    /// # Arguments
    ///
    /// * `signature` - The signature of message digest.
    /// * `space` - The address of the space contract.
    /// * `author` - The starknet address of the author of the proposal.
    /// * `metadata_uri` - The URI of the proposal metadata.
    /// * `execution_strategy` - The execution strategy of the proposal.
    /// * `user_proposal_validation_params` - The user proposal validation params of the proposal.
    /// * `salt` - The salt, used for replay protection.
    fn authenticate_propose(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: ContractAddress,
        metadata_uri: Array<felt252>,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252
    );


    /// Authenticates a vote transaction using the starknet EIP712-equivalent signature scheme.
    /// Note: Salt is not needed because double voting is prevented by the space itself.
    /// Note: Only SNIP-6 compliant accounts are supported.
    ///
    /// # Arguments
    ///
    /// * `signature` - The signature of message digest.
    /// * `space` - The address of the space contract.
    /// * `voter` - The starknet address of the voter.
    /// * `proposal_id` - The id of the proposal.
    /// * `choice` - The choice of the voter.
    /// * `user_voting_strategies` - The user voting strategies of the voter.
    /// * `metadata_uri` - The URI of the proposal metadata.
    fn authenticate_vote(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_uri: Array<felt252>
    );

    /// Authenticates an update proposal transaction using the starknet EIP712-equivalent signature scheme.
    /// Note: Only SNIP-6 compliant accounts are supported.
    ///
    /// # Arguments
    ///
    /// * `signature` - The signature of message digest.
    /// * `space` - The address of the space contract.
    /// * `author` - The starknet address of the author of the proposal.
    /// * `proposal_id` - The id of the proposal.
    /// * `execution_strategy` - The execution strategy of the proposal.
    /// * `metadata_uri` - The URI of the proposal metadata.
    /// * `salt` - The salt, used for replay protection.
    fn authenticate_update_proposal(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_uri: Array<felt252>,
        salt: felt252
    );
}

#[starknet::contract]
mod StarkSigAuthenticator {
    use super::IStarkSigAuthenticator;
    use starknet::{ContractAddress, info};
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::types::{Strategy, IndexedStrategy, UserAddress, Choice};
    use sx::utils::SNIP12;

    #[storage]
    struct Storage {
        _used_salts: LegacyMap::<(ContractAddress, felt252), bool>
    }

    #[abi(embed_v0)]
    impl StarkSigAuthenticator of IStarkSigAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            author: ContractAddress,
            metadata_uri: Array<felt252>,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252
        ) {
            assert(!self._used_salts.read((author, salt)), 'Salt Already Used');

            let state = SNIP12::unsafe_new_contract_state();
            SNIP12::InternalImpl::verify_propose_sig(
                @state,
                signature,
                space,
                author,
                metadata_uri.span(),
                @execution_strategy,
                user_proposal_validation_params.span(),
                salt
            );

            self._used_salts.write((author, salt), true);
            ISpaceDispatcher { contract_address: space }
                .propose(
                    UserAddress::Starknet(author),
                    metadata_uri,
                    execution_strategy,
                    user_proposal_validation_params,
                );
        }

        fn authenticate_vote(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_uri: Array<felt252>
        ) {
            // No need to check salts here, as double voting is prevented by the space itself.

            let state = SNIP12::unsafe_new_contract_state();
            SNIP12::InternalImpl::verify_vote_sig(
                @state,
                signature,
                space,
                voter,
                proposal_id,
                choice,
                user_voting_strategies.span(),
                metadata_uri.span()
            );

            ISpaceDispatcher { contract_address: space }
                .vote(
                    UserAddress::Starknet(voter),
                    proposal_id,
                    choice,
                    user_voting_strategies,
                    metadata_uri,
                );
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_uri: Array<felt252>,
            salt: felt252
        ) {
            assert(!self._used_salts.read((author, salt)), 'Salt Already Used');

            let state = SNIP12::unsafe_new_contract_state();
            SNIP12::InternalImpl::verify_update_proposal_sig(
                @state,
                signature,
                space,
                author,
                proposal_id,
                @execution_strategy,
                metadata_uri.span(),
                salt
            );

            self._used_salts.write((author, salt), true);
            ISpaceDispatcher { contract_address: space }
                .update_proposal(
                    UserAddress::Starknet(author), proposal_id, execution_strategy, metadata_uri
                );
        }
    }
    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, version: felt252) {
        let mut state = SNIP12::unsafe_new_contract_state();
        SNIP12::InternalImpl::initializer(ref state, name, version);
    }
}
