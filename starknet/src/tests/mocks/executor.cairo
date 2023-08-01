#[starknet::contract]
mod ExecutorExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use sx::utils::types::{Proposal, ProposalStatus};
    use sx::execution_strategies::simple_quorum::SimpleQuorumExecutionStrategy;
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
            call_contract_syscall(tx.target, tx.selector, tx.data.span()).unwrap_syscall();
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
