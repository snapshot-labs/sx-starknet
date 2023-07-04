use starknet::ContractAddress;
use starknet::SyscallResult;
use sx::utils::types::{Strategy, IndexedStrategy, Choice};

#[abi]
trait IEthSigAuthenticator {
    #[external]
    fn authenticate_propose(
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: u256,
    );
    #[external]
    fn authenticate_vote(
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>
    );
    #[external]
    fn authenticate_update_proposal(
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        salt: u256
    );
}

#[contract]
mod EthSigAuthenticator {
    use super::IEthSigAuthenticator;
    use starknet::ContractAddress;
    use starknet::syscalls::call_contract_syscall;
    use core::array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::types::{Strategy, IndexedStrategy, Choice};
    use sx::utils::signatures;

    struct Storage {
        _domain_hash: u256,
        _used_salts: LegacyMap::<(ContractAddress, u256), bool>
    }


    impl EthSigAuthenticator of IEthSigAuthenticator {
        fn authenticate_propose(
            r: u256,
            s: u256,
            v: u256,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            salt: u256,
        ) {
            signatures::verify_propose_sig(
                r,
                s,
                v,
                _domain_hash::read(),
                target,
                author,
                execution_strategy.clone(),
                user_proposal_validation_params.clone(),
                salt,
            );
            _used_salts::write((author, salt), true);

            ISpaceDispatcher {
                contract_address: target
            }.propose(author, execution_strategy, user_proposal_validation_params);
        }

        fn authenticate_vote(
            r: u256,
            s: u256,
            v: u256,
            target: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>
        ) {
            signatures::verify_vote_sig(
                r,
                s,
                v,
                _domain_hash::read(),
                target,
                voter,
                proposal_id,
                choice,
                user_voting_strategies.clone()
            );

            // No need to check salts here, as double voting is prevented by the space itself.

            ISpaceDispatcher {
                contract_address: target
            }.vote(voter, proposal_id, choice, user_voting_strategies);
        }

        fn authenticate_update_proposal(
            r: u256,
            s: u256,
            v: u256,
            target: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            salt: u256
        ) {
            signatures::verify_update_proposal_sig(
                r,
                s,
                v,
                _domain_hash::read(),
                target,
                author,
                proposal_id,
                execution_strategy.clone(),
                salt
            );
            _used_salts::write((author, salt), true);

            ISpaceDispatcher {
                contract_address: target
            }.update_proposal(author, proposal_id, execution_strategy);
        }
    }

    #[constructor]
    fn constructor(name: felt252, version: felt252) {
        // TODO: domain hash is immutable so could be placed in the contract code instead of storage to save on reads.
        _domain_hash::write(signatures::get_domain_hash(name, version));
    }

    #[external]
    fn authenticate_propose(
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        salt: u256,
    ) {
        EthSigAuthenticator::authenticate_propose(
            r, s, v, target, author, execution_strategy, user_proposal_validation_params, salt
        );
    }

    #[external]
    fn authenticate_vote(
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>
    ) {
        EthSigAuthenticator::authenticate_vote(
            r, s, v, target, voter, proposal_id, choice, user_voting_strategies
        );
    }

    #[external]
    fn authenticate_update_proposal(
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        salt: u256
    ) {
        EthSigAuthenticator::authenticate_update_proposal(
            r, s, v, target, author, proposal_id, execution_strategy, salt
        );
    }
}
