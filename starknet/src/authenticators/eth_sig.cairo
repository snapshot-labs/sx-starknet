use starknet::{ContractAddress, EthAddress};
use starknet::SyscallResult;
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IEthSigAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        author: EthAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        metadata_uri: Array<felt252>,
        salt: u256,
    );
    fn authenticate_vote(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        voter: EthAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_uri: Array<felt252>,
    );
    fn authenticate_update_proposal(
        ref self: TContractState,
        r: u256,
        s: u256,
        v: u256,
        target: ContractAddress,
        author: EthAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_uri: Array<felt252>,
        salt: u256
    );
}

#[starknet::contract]
mod EthSigAuthenticator {
    use super::IEthSigAuthenticator;
    use starknet::{ContractAddress, EthAddress, syscalls::call_contract_syscall};
    use core::array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use sx::space::space::{ISpaceDispatcher, ISpaceDispatcherTrait};
    use sx::types::{Strategy, IndexedStrategy, Choice, UserAddress};
    use sx::utils::{signatures, legacy_hash::LegacyHashEthAddress};

    #[storage]
    struct Storage {
        _domain_hash: u256,
        _used_salts: LegacyMap::<(EthAddress, u256), bool>
    }

    #[external(v0)]
    impl EthSigAuthenticator of IEthSigAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u256,
            target: ContractAddress,
            author: EthAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            metadata_uri: Array<felt252>,
            salt: u256,
        ) {
            signatures::verify_propose_sig(
                r,
                s,
                v,
                self._domain_hash.read(),
                target,
                author,
                execution_strategy.clone(),
                user_proposal_validation_params.clone(),
                salt,
            );
            self._used_salts.write((author, salt), true);

            ISpaceDispatcher {
                contract_address: target
            }
                .propose(
                    UserAddress::Ethereum(author),
                    execution_strategy,
                    user_proposal_validation_params,
                    metadata_uri
                );
        }

        fn authenticate_vote(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u256,
            target: ContractAddress,
            voter: EthAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_uri: Array<felt252>,
        ) {
            signatures::verify_vote_sig(
                r,
                s,
                v,
                self._domain_hash.read(),
                target,
                voter,
                proposal_id,
                choice,
                user_voting_strategies.clone(),
            );

            // No need to check salts here, as double voting is prevented by the space itself.

            ISpaceDispatcher {
                contract_address: target
            }
                .vote(
                    UserAddress::Ethereum(voter),
                    proposal_id,
                    choice,
                    user_voting_strategies,
                    metadata_uri
                );
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            r: u256,
            s: u256,
            v: u256,
            target: ContractAddress,
            author: EthAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_uri: Array<felt252>,
            salt: u256
        ) {
            signatures::verify_update_proposal_sig(
                r,
                s,
                v,
                self._domain_hash.read(),
                target,
                author,
                proposal_id,
                execution_strategy.clone(),
                salt
            );
            self._used_salts.write((author, salt), true);

            ISpaceDispatcher {
                contract_address: target
            }
                .update_proposal(
                    UserAddress::Ethereum(author), proposal_id, execution_strategy, metadata_uri
                );
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, version: felt252) {
        // TODO: domain hash is immutable so could be placed in the contract code instead of storage to save on reads.
        self._domain_hash.write(signatures::get_domain_hash(name, version));
    }
}
