use starknet::{ContractAddress, EthAddress};
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IEthTxAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        target: ContractAddress,
        author: EthAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        metadata_URI: Array<felt252>
    );
    fn authenticate_vote(
        ref self: TContractState,
        target: ContractAddress,
        voter: EthAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_URI: Array<felt252>
    );
    fn authenticate_update_proposal(
        ref self: TContractState,
        target: ContractAddress,
        author: EthAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_URI: Array<felt252>
    );
// TODO: Should L1 handlers be part of the interface?
}

#[starknet::contract]
mod EthTxAuthenticator {
    use super::IEthTxAuthenticator;
    use starknet::{ContractAddress, EthAddress, Felt252TryIntoEthAddress, EthAddressIntoFelt252};
    use starknet::syscalls::call_contract_syscall;
    use core::serde::Serde;
    use core::array::{ArrayTrait, SpanTrait};
    use traits::{PartialEq, TryInto, Into};
    use option::OptionTrait;
    use zeroable::Zeroable;
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::types::{UserAddress, Strategy, IndexedStrategy, Choice};
    use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};

    #[storage]
    struct Storage {
        _starknet_commit_address: EthAddress,
        _commits: LegacyMap::<felt252, EthAddress>
    }

    #[external(v0)]
    impl EthTxAuthenticator of IEthTxAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            target: ContractAddress,
            author: EthAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            metadata_URI: Array<felt252>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            PROPOSE_SELECTOR.serialize(ref payload);
            author.serialize(ref payload);
            execution_strategy.serialize(ref payload);
            user_proposal_validation_params.serialize(ref payload);
            metadata_URI.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(ref self, payload_hash, author);

            ISpaceDispatcher {
                contract_address: target
            }
                .propose(
                    UserAddress::Ethereum(author),
                    execution_strategy,
                    user_proposal_validation_params,
                    metadata_URI
                );
        }

        fn authenticate_vote(
            ref self: ContractState,
            target: ContractAddress,
            voter: EthAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_URI: Array<felt252>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            VOTE_SELECTOR.serialize(ref payload);
            voter.serialize(ref payload);
            proposal_id.serialize(ref payload);
            choice.serialize(ref payload);
            user_voting_strategies.serialize(ref payload);
            metadata_URI.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(ref self, payload_hash, voter);

            ISpaceDispatcher {
                contract_address: target
            }
                .vote(
                    UserAddress::Ethereum(voter),
                    proposal_id,
                    choice,
                    user_voting_strategies,
                    metadata_URI
                );
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            target: ContractAddress,
            author: EthAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_URI: Array<felt252>
        ) {
            let mut payload = ArrayTrait::<felt252>::new();
            target.serialize(ref payload);
            UPDATE_PROPOSAL_SELECTOR.serialize(ref payload);
            author.serialize(ref payload);
            proposal_id.serialize(ref payload);
            execution_strategy.serialize(ref payload);
            metadata_URI.serialize(ref payload);
            let payload_hash = poseidon::poseidon_hash_span(payload.span());

            consume_commit(ref self, payload_hash, author);

            ISpaceDispatcher {
                contract_address: target
            }
                .update_proposal(
                    UserAddress::Ethereum(author), proposal_id, execution_strategy, metadata_URI
                );
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, starknet_commit_address: EthAddress) {
        self._starknet_commit_address.write(starknet_commit_address);
    }

    #[l1_handler]
    fn commit(
        ref self: ContractState, from_address: felt252, sender_address: felt252, hash: felt252
    ) {
        assert(
            from_address == self._starknet_commit_address.read().into(), 'Invalid commit address'
        );
        // Prevents hash being overwritten by a different sender.
        assert(self._commits.read(hash).into() == 0, 'Commit already exists');
        self._commits.write(hash, sender_address.try_into().unwrap());
    }

    fn consume_commit(ref self: ContractState, hash: felt252, sender_address: EthAddress) {
        let committer_address = self._commits.read(hash);
        assert(committer_address.is_zero(), 'Commit not found');
        assert(committer_address == sender_address, 'Invalid sender address');
        // Delete the commit to prevent replay attacks.
        self._commits.write(hash, Zeroable::zero());
    }
}
