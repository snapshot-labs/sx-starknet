use starknet::{ContractAddress};
use sx::types::{Strategy, IndexedStrategy, Choice};

#[starknet::interface]
trait IStarkTxAuthenticator<TContractState> {
    fn authenticate_propose(
        ref self: TContractState,
        space: ContractAddress,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        metadata_URI: Array<felt252>
    );
    fn authenticate_vote(
        ref self: TContractState,
        space: ContractAddress,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_URI: Array<felt252>
    );
    fn authenticate_update_proposal(
        ref self: TContractState,
        space: ContractAddress,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_URI: Array<felt252>
    );
}

#[starknet::contract]
mod StarkTxAuthenticator {
    use super::IStarkTxAuthenticator;
    use starknet::{ContractAddress, info};
    use core::array::ArrayTrait;
    use sx::{
        space::space::{ISpaceDispatcher, ISpaceDispatcherTrait},
        types::{UserAddress, Strategy, IndexedStrategy, Choice},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl StarkTxAuthenticator of IStarkTxAuthenticator<ContractState> {
        fn authenticate_propose(
            ref self: ContractState,
            space: ContractAddress,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            metadata_URI: Array<felt252>
        ) {
            assert(info::get_caller_address() == author, 'Invalid Caller');

            ISpaceDispatcher { contract_address: space }
                .propose(
                    UserAddress::Starknet(author),
                    execution_strategy,
                    user_proposal_validation_params,
                    metadata_URI
                );
        }

        fn authenticate_vote(
            ref self: ContractState,
            space: ContractAddress,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_URI: Array<felt252>
        ) {
            assert(info::get_caller_address() == voter, 'Invalid Caller');

            ISpaceDispatcher { contract_address: space }
                .vote(
                    UserAddress::Starknet(voter),
                    proposal_id,
                    choice,
                    user_voting_strategies,
                    metadata_URI
                );
        }

        fn authenticate_update_proposal(
            ref self: ContractState,
            space: ContractAddress,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_URI: Array<felt252>
        ) {
            assert(info::get_caller_address() == author, 'Invalid Caller');

            ISpaceDispatcher { contract_address: space }
                .update_proposal(
                    UserAddress::Starknet(author), proposal_id, execution_strategy, metadata_URI
                );
        }
    }
}
