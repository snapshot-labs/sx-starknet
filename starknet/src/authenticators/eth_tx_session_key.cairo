use starknet::{ContractAddress, EthAddress};
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IEthTxSessionKeyAuthenticator<TContractState> {
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

    fn register_with_owner_tx(
        ref self: TContractState,
        owner: EthAddress,
        session_public_key: felt252,
        session_duration: u32,
    );

    fn revoke_with_owner_tx(
        ref self: TContractState, owner: EthAddress, session_public_key: felt252
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
    use core::traits::AddEq;
    use super::IEthTxSessionKeyAuthenticator;
    use starknet::{ContractAddress, EthAddress};
    use sx::interfaces::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::types::{Strategy, IndexedStrategy, Choice, UserAddress};
    use sx::utils::{
        SessionKey, StarkEIP712SessionKey, LegacyHashFelt252EthAddress, LegacyHashUsedSalts
    };
    use sx::utils::constants::{
        REGISTER_SESSION_WITH_OWNER_TX_SELECTOR, REVOKE_SESSION_WITH_OWNER_TX_SELECTOR
    };
    #[storage]
    struct Storage {
        _used_salts: LegacyMap::<(EthAddress, u256), bool>,
        _starknet_commit_address: EthAddress,
        _commits: LegacyMap::<(felt252, EthAddress), bool>
    }

    #[external(v0)]
    impl EthTxSessionKeyAuthenticator of IEthTxSessionKeyAuthenticator<ContractState> {
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

        fn register_with_owner_tx(
            ref self: ContractState,
            owner: EthAddress,
            session_public_key: felt252,
            session_duration: u32,
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::register_with_owner_tx(
                ref state, owner, session_public_key, session_duration
            );
        }

        fn revoke_with_owner_tx(
            ref self: ContractState, owner: EthAddress, session_public_key: felt252
        ) {
            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::revoke_with_owner_tx(ref state, owner, session_public_key);
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
    fn constructor(
        ref self: ContractState,
        name: felt252,
        version: felt252,
        starknet_commit_address: EthAddress
    ) {
        let mut state = SessionKey::unsafe_new_contract_state();
        SessionKey::InternalImpl::eth_tx_initializer(
            ref state, name, version, starknet_commit_address
        );
    }

    #[l1_handler]
    fn commit(
        ref self: ContractState, from_address: felt252, sender_address: felt252, hash: felt252
    ) {
        let mut state = SessionKey::unsafe_new_contract_state();
        SessionKey::InternalImpl::commit(ref state, from_address, sender_address, hash);
    }
}
