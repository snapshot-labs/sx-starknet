use starknet::ContractAddress;
use sx::types::{Proposal, ProposalStatus};

#[starknet::interface]
trait ITimelockExecutionStrategy<TContractState> {
    fn execute(
        ref self: TContractState,
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<felt252>
    );

    fn execute_queued_proposal(ref self: TContractState, payload: Array<felt252>);

    fn veto(ref self: TContractState, payload_hash: felt252);

    fn set_veto_guardian(ref self: TContractState, new_veto_guardian: ContractAddress);

    fn set_timelock_delay(ref self: TContractState, new_timelock_delay: u256);

    fn get_proposal_status(
        self: @TContractState,
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
    ) -> ProposalStatus;

    fn get_strategy_type(self: @TContractState) -> felt252;
}

#[starknet::contract]
mod TimelockExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use super::ITimelockExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};
    use sx::utils::simple_majority;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl ExecutionStrategy of IExecutionStrategy<ContractState> {
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            let proposal_status = self
                .get_proposal_status(proposal, votes_for, votes_against, votes_abstain,);
            assert(proposal_status == ProposalStatus::Accepted(()), 'Invalid Proposal Status');
        }

        fn get_proposal_status(
            self: @ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            simple_majority::get_proposal_status(@proposal, votes_for, votes_against, votes_abstain)
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'SimpleQuorumTimelock'
        }
    }
}
