use starknet::{ContractAddress, EthAddress};
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IEthSigSessionKeyAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        signature: Array<felt252>,
        space: ContractAddress,
        author: EthAddress,
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
        voter: EthAddress,
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
        author: EthAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_uri: Array<felt252>,
        salt: felt252,
        session_public_key: felt252
    );

    fn register_with_owner_sig(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u32,
        owner: EthAddress,
        session_public_key: felt252,
        session_duration: u32,
        salt: u256,
    );

    fn revoke_with_owner_sig(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u32,
        owner: EthAddress,
        session_public_key: felt252,
        salt: u256,
    );

    fn revoke_with_session_key_sig(
        ref self: TContractState,
        signature: Array<felt252>,
        owner: EthAddress,
        salt: felt252,
        session_public_key: felt252
    );
}

#[starknet::contract]
mod EthSigSessionKeyAuthenticator {
    use super::IEthSigSessionKeyAuthenticator;
    use starknet::{ContractAddress, EthAddress};
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::types::{Strategy, IndexedStrategy, Choice, UserAddress};
    use sx::utils::{
        EIP712, SessionKey, StarkEIP712SessionKey, LegacyHashEthAddress, LegacyHashUsedSalts,
        ByteReverse
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl EthSigSessionKeyAuthenticator of IEthSigSessionKeyAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            signature: Array<felt252>,
            space: ContractAddress,
            author: EthAddress,
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
                author,
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
            voter: EthAddress,
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
                voter,
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
            author: EthAddress,
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
                author,
                proposal_id,
                execution_strategy,
                metadata_uri,
                salt,
                session_public_key
            );
        }


        fn register_with_owner_sig(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            owner: EthAddress,
            session_public_key: felt252,
            session_duration: u32,
            salt: u256,
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::register_with_owner_sig(
                ref state, r, s, v, owner, session_public_key, session_duration, salt
            );
        }

        fn revoke_with_owner_sig(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            owner: EthAddress,
            session_public_key: felt252,
            salt: u256,
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::revoke_with_owner_sig(
                ref state, r, s, v, owner, session_public_key, salt
            );
        }

        fn revoke_with_session_key_sig(
            ref self: ContractState,
            signature: Array<felt252>,
            owner: EthAddress,
            salt: felt252,
            session_public_key: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::revoke_with_session_key_sig(
                ref state, signature, owner, salt, session_public_key
            );
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, version: felt252,) {
        let mut state = SessionKey::unsafe_new_contract_state();
        SessionKey::InternalImpl::eth_sig_initializer(ref state, name, version);
    }
}
