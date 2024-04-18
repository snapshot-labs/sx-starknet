use starknet::ContractAddress;
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IStarkTxSessionKeyAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: ContractAddress,
        metadata_uri: Array<felt252>,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252,
        session_public_key: felt252
    );

    fn authenticate_vote(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_uri: Array<felt252>,
        session_public_key: felt252
    );

    fn authenticate_update_proposal(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_uri: Array<felt252>,
        salt: felt252,
        session_public_key: felt252
    );

    fn register_with_owner_tx(
        ref self: TContractState,
        owner: ContractAddress,
        session_public_key: felt252,
        session_duration: u32
    );

    fn revoke_with_owner_tx(
        ref self: TContractState, owner: ContractAddress, session_public_key: felt252
    );

    fn revoke_with_session_key_sig(
        ref self: TContractState,
        signature: Array<felt252>,
        owner: ContractAddress,
        session_public_key: felt252,
        salt: felt252
    );
}

#[starknet::contract]
mod StarkTxSessionKeyAuthenticator {
    use super::IStarkTxSessionKeyAuthenticator;
    use starknet::ContractAddress;
    use sx::types::{Strategy, IndexedStrategy, Choice, UserAddress};
    use sx::utils::SessionKey;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl StarkTxSessionKeyAuthenticator of IStarkTxSessionKeyAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            author: ContractAddress,
            metadata_uri: Array<felt252>,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
            session_public_key: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::authenticate_propose(
                ref state,
                signature,
                space,
                UserAddress::Starknet(author),
                metadata_uri,
                execution_strategy,
                user_proposal_validation_params,
                salt,
                session_public_key
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
            metadata_uri: Array<felt252>,
            session_public_key: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::authenticate_vote(
                ref state,
                signature,
                space,
                UserAddress::Starknet(voter),
                proposal_id,
                choice,
                user_voting_strategies,
                metadata_uri,
                session_public_key
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
            salt: felt252,
            session_public_key: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::authenticate_update_proposal(
                ref state,
                signature,
                space,
                UserAddress::Starknet(author),
                proposal_id,
                execution_strategy,
                metadata_uri,
                salt,
                session_public_key
            );
        }

        fn register_with_owner_tx(
            ref self: ContractState,
            owner: ContractAddress,
            session_public_key: felt252,
            session_duration: u32
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::register_with_owner_stark_tx(
                ref state, owner, session_public_key, session_duration
            );
        }

        fn revoke_with_owner_tx(
            ref self: ContractState, owner: ContractAddress, session_public_key: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::revoke_with_owner_stark_tx(
                ref state, owner, session_public_key
            );
        }

        fn revoke_with_session_key_sig(
            ref self: ContractState,
            signature: Array<felt252>,
            owner: ContractAddress,
            session_public_key: felt252,
            salt: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::revoke_with_session_key_sig(
                ref state, signature, UserAddress::Starknet(owner), session_public_key, salt
            );
        }
    }
}
