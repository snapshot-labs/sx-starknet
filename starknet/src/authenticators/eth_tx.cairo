use starknet::ContractAddress;
use sx::utils::sx_types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IEthTxAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        target: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>
    );
    fn authenticate_vote(
        ref self: TContractState,
        target: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>
    );
    fn authenticate_update_proposal(
        ref self: TContractState,
        target: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy
    );
// TODO: Should L1 handlers be part of the interface?
}

#[starknet::contract]
mod EthTxAuthenticator {
    use super::IEthTxAuthenticator;
    use starknet::{ContractAddress, contract_address_to_felt252};
    use starknet::syscalls::call_contract_syscall;
    use core::serde::Serde;
    use core::array::{ArrayTrait, SpanTrait};
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::utils::sx_types::{Strategy, IndexedStrategy, Choice};
    use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};

    #[storage]
    struct Storage {
        _starknet_commit_address: felt252,
        _commits: LegacyMap::<felt252, felt252>
    }

    #[external(v0)]
    impl EthTxAuthenticator of IEthTxAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            target: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            PROPOSE_SELECTOR.serialize(ref payload);
            author.serialize(ref payload);
            execution_strategy.serialize(ref payload);
            user_proposal_validation_params.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(ref self, payload_hash, contract_address_to_felt252(author));

            ISpaceDispatcher {
                contract_address: target
            }.propose(author, execution_strategy, user_proposal_validation_params);
        }

        fn authenticate_vote(
            ref self: ContractState,
            target: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            VOTE_SELECTOR.serialize(ref payload);
            voter.serialize(ref payload);
            proposal_id.serialize(ref payload);
            choice.serialize(ref payload);
            user_voting_strategies.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(ref self, payload_hash, contract_address_to_felt252(voter));

            ISpaceDispatcher {
                contract_address: target
            }.vote(voter, proposal_id, choice, user_voting_strategies);
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            target: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            UPDATE_PROPOSAL_SELECTOR.serialize(ref payload);
            author.serialize(ref payload);
            proposal_id.serialize(ref payload);
            execution_strategy.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(ref self, payload_hash, contract_address_to_felt252(author));

            ISpaceDispatcher {
                contract_address: target
            }.update_proposal(author, proposal_id, execution_strategy);
        }
    }

    #[l1_handler]
    fn commit(
        ref self: ContractState, from_address: felt252, sender_address: felt252, hash: felt252
    ) {
        assert(from_address == self._starknet_commit_address.read(), 'Invalid commit address');
        self._commits.write(hash, sender_address);
    }

    fn consume_commit(ref self: ContractState, hash: felt252, sender_address: felt252) {
        let committer_address = self._commits.read(hash);
        assert(committer_address != 0, 'Commit not found');
        assert(committer_address == sender_address, 'Invalid sender address');
        // Delete the commit to prevent replay attacks.
        self._commits.write(hash, 0);
    }
}
