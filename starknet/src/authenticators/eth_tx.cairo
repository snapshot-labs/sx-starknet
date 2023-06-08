use core::zeroable::Zeroable;
use starknet::ContractAddress;
use starknet::SyscallResult;
use sx::utils::types::{Strategy, IndexedStrategy, Choice};
 
#[abi]
trait IEthTxAuthenticator {
    #[external]
    fn authenticate_propose(
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>
    );
    #[external]
    fn authenticate_vote(
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>
    );
    #[external]
    fn authenticate_update_proposal(
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy
    );
    #[l1_handler]
    fn commit(from_address: felt252, sender_address: felt252, hash: felt252);
}

#[contract]
mod EthTxAuthenticator {
    use super::IEthTxAuthenticator;
    use starknet::{ContractAddress, contract_address_to_felt252};
    use starknet::syscalls::call_contract_syscall;
    use core::serde::Serde;
    use core::array::{ArrayTrait, SpanTrait};
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::types::{Strategy, IndexedStrategy, Choice};

    struct Storage {
        _starknet_commit_address: felt252,
        _commits: LegacyMap::<felt252, felt252>
    }

    impl EthTxAuthenticator of IEthTxAuthenticator {
        fn authenticate_propose(
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            author.serialize(ref payload);
            execution_strategy.serialize(ref payload);
            user_proposal_validation_params.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(payload_hash, contract_address_to_felt252(author));

            ISpaceDispatcher {
                contract_address: target
            }.propose(author, execution_strategy, user_proposal_validation_params);
        }

        fn authenticate_vote(
            target: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            voter.serialize(ref payload);
            proposal_id.serialize(ref payload);
            choice.serialize(ref payload);
            user_voting_strategies.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(payload_hash, contract_address_to_felt252(voter));

            ISpaceDispatcher {
                contract_address: target
            }.vote(voter, proposal_id, choice, user_voting_strategies);
        }

        fn authenticate_update_proposal(
            target: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            author.serialize(ref payload);
            proposal_id.serialize(ref payload);
            execution_strategy.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(payload_hash, contract_address_to_felt252(author));

            ISpaceDispatcher {
                contract_address: target
            }.update_proposal(author, proposal_id, execution_strategy);
        }

        fn commit(from_address: felt252, sender_address: felt252, hash: felt252) {
            assert(from_address == _starknet_commit_address::read(), 'Invalid commit address');
            _commits::write(hash, sender_address);
        }
    }

    #[external]
    fn authenticate_propose(
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>
    ) {
        EthTxAuthenticator::authenticate_propose(
            target, author, execution_strategy, user_proposal_validation_params
        );
    }

    #[external]
    fn authenticate_vote(
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>
    ) {
        EthTxAuthenticator::authenticate_vote(
            target, voter, proposal_id, choice, user_voting_strategies
        );
    }

    #[external]
    fn authenticate_update_proposal(
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy
    ) {
        EthTxAuthenticator::authenticate_update_proposal(
            target, author, proposal_id, execution_strategy
        );
    }

    #[l1_handler]
    fn commit(from_address: felt252, sender_address: felt252, hash: felt252) {
        EthTxAuthenticator::commit(from_address, sender_address, hash);
    }

    fn consume_commit(hash: felt252, sender_address: felt252) {
        let committer_address = _commits::read(hash);
        assert(committer_address != 0, 'Commit not found');
        assert(committer_address == sender_address, 'Invalid sender address');
        // Delete the commit to prevent replay attacks.
        _commits::write(hash, 0);
    }
}
