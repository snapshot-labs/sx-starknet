use starknet::ContractAddress;
use starknet::SyscallResult;
use sx::utils::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IStarkSigAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        r: felt252,
        s: felt252,
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: felt252,
        public_key: felt252,
    );
    fn authenticate_vote(
        ref self: TContractState,
        r: felt252,
        s: felt252,
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        public_key: felt252
    );
    fn authenticate_update_proposal(
        ref self: TContractState,
        r: felt252,
        s: felt252,
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        salt: felt252,
        public_key: felt252
    );
}

#[starknet::contract]
mod StarkSigAuthenticator {
    use super::IStarkSigAuthenticator;
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use core::array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use serde::Serde;
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::types::{Strategy, IndexedStrategy, Choice};
    use sx::utils::stark_signatures;
    use sx::interfaces::{IAccountDispatcher, IAccountDispatcherTrait};

    #[storage]
    struct Storage {
        _domain_hash: felt252,
        _used_salts: LegacyMap::<(ContractAddress, felt252), bool>
    }

    #[external(v0)]
    impl StarkSigAuthenticator of IStarkSigAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: felt252,
            public_key: felt252,
        ) {
            stark_signatures::verify_propose_sig(
                self._domain_hash.read(),
                r,
                s,
                target,
                author,
                execution_strategy,
                user_proposal_validation_params,
                salt,
                public_key
            );
            // Check public key corresponds to the author account address. 
            assert_valid_account(author, public_key);

            self._used_salts.write((author, salt), true);
        // ISpaceDispatcher {
        //     contract_address: target
        // }.propose(author, execution_strategy, user_proposal_validation_params);
        }

        fn authenticate_vote(
            ref self: ContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            public_key: felt252
        ) {
            stark_signatures::verify_vote_sig(
                self._domain_hash.read(),
                r,
                s,
                target,
                voter,
                proposal_id,
                choice,
                user_voting_strategies,
                public_key
            );

            // Check public key corresponds to the voter account address.
            assert_valid_account(voter, public_key);
        // No need to check salts here, as double voting is prevented by the space itself.

        // ISpaceDispatcher {
        //     contract_address: target
        // }.vote(voter, proposal_id, choice, user_voting_strategies);
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            r: felt252,
            s: felt252,
            target: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            salt: felt252,
            public_key: felt252
        ) {
            stark_signatures::verify_update_proposal_sig(
                self._domain_hash.read(),
                r,
                s,
                target,
                author,
                proposal_id,
                execution_strategy,
                salt,
                public_key
            );
            // Check public key corresponds to the author account address.
            assert_valid_account(author, public_key);

            self._used_salts.write((author, salt), true);
        // ISpaceDispatcher {
        //     contract_address: target
        // }.update_proposal(author, proposal_id, execution_strategy);
        }
    }
    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, version: felt252
    ) { // TODO: domain hash is immutable so could be placed in the contract code instead of storage to save on reads.
        self._domain_hash.write(stark_signatures::get_domain_hash(name, version));
    }

    fn assert_valid_account(address: ContractAddress, public_key: felt252) {
        // TODO: should query the supportsInterface function before calling getPublicKey.
        // What should the interface id be?
        assert(
            IAccountDispatcher { contract_address: address }.getPublicKey() == public_key,
            'Invalid public key'
        );
    }
}
