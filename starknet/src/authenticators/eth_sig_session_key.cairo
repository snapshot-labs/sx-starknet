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
    // fn authenticate_vote(
    //     ref self: TContractState,
    //     signature: Array<felt252>,
    //     space: ContractAddress,
    //     voter: ContractAddress,
    //     proposal_id: u256,
    //     choice: Choice,
    //     user_voting_strategies: Array<IndexedStrategy>,
    //     metadata_uri: Array<felt252>,
    //     session_public_key: felt252
    // );

    // fn authenticate_update_proposal(
    //     ref self: TContractState,
    //     signature: Array<felt252>,
    //     space: ContractAddress,
    //     author: ContractAddress,
    //     proposal_id: u256,
    //     execution_strategy: Strategy,
    //     metadata_uri: Array<felt252>,
    //     salt: felt252,
    //     session_public_key: felt252
    // );

    fn authorize_with_owner_sig(
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
// fn revoke_with_session_key_sig(
//     ref self: TContractState, sig: Array<felt252>, salt: felt252, session_public_key: felt252
// );
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
    struct Storage {
        _used_salts: LegacyMap::<(EthAddress, u256), bool>,
    }

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
            let state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::assert_valid_session_key(
                @state, session_public_key, UserAddress::Ethereum(author)
            );

            assert(!self._used_salts.read((author, salt.into())), 'Salt Already Used');

            let state = StarkEIP712SessionKey::unsafe_new_contract_state();
            StarkEIP712SessionKey::InternalImpl::verify_propose_sig(
                @state,
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
                    UserAddress::Ethereum(author),
                    metadata_uri,
                    execution_strategy,
                    user_proposal_validation_params,
                );
        }

        fn authorize_with_owner_sig(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u32,
            owner: EthAddress,
            session_public_key: felt252,
            session_duration: u32,
            salt: u256,
        ) {
            assert(!self._used_salts.read((owner, salt)), 'Salt Already Used');

            let state = EIP712::unsafe_new_contract_state();
            EIP712::InternalImpl::verify_session_key_auth_sig(
                @state, r, s, v, owner, session_public_key, session_duration, salt
            );

            self._used_salts.write((owner, salt), true);

            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::register(
                ref state, UserAddress::Ethereum(owner), session_public_key, session_duration
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
            assert(!self._used_salts.read((owner, salt)), 'Salt Already Used');

            let state = EIP712::unsafe_new_contract_state();
            EIP712::InternalImpl::verify_session_key_revoke_sig(
                @state, r, s, v, owner, session_public_key, salt
            );

            self._used_salts.write((owner, salt), true);

            let mut state = SessionKey::unsafe_new_contract_state();
            SessionKey::InternalImpl::revoke(
                ref state, UserAddress::Ethereum(owner), session_public_key
            );
        }
    }
}
