#[starknet::contract]
mod ExecutorExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};
    use starknet::ContractAddress;
    use core::serde::Serde;
    use core::array::ArrayTrait;
    use option::OptionTrait;
    use starknet::syscalls::call_contract_syscall;

    #[storage]
    struct Storage {}

    #[derive(Drop, Serde)]
    struct Transaction {
        target: ContractAddress,
        selector: felt252,
        data: Array<felt252>,
    }

    #[external(v0)]
    impl ExecutorExecutionStrategy of IExecutionStrategy<ContractState> {
        // Dummy function that will just execute the `Transaction` in the payload, without needing any quorum.
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            let mut sp4n = payload.span();
            let tx: Transaction = Serde::<Transaction>::deserialize(ref sp4n).unwrap();
            call_contract_syscall(tx.target, tx.selector, tx.data.span()).unwrap();
        }

        fn get_proposal_status(
            self: @ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            panic_with_felt252('unimplemented');
            ProposalStatus::Cancelled(())
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'Executor'
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}
}


#[starknet::contract]
mod ExecutorWithoutTxExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};
    use core::array::ArrayTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl ExecutorWithoutTxExecutionStrategy of IExecutionStrategy<ContractState> {
        // Dummy function that will do nothing
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {}

        fn get_proposal_status(
            self: @ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            panic_with_felt252('unimplemented');
            ProposalStatus::Cancelled(())
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'ExecutorWithoutTx'
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
