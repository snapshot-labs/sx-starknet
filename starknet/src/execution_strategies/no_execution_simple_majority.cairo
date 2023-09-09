/// Execution strategy that will not execute anything but ensure that the
/// proposal is in the status `Accepted` or `VotingPeriodAccepted` by following
/// the `SimpleMajority` rule (`votes_for > votes_against`).
#[starknet::contract]
mod NoExecutionSimpleMajorityExecutionStrategy {
    use sx::interfaces::IExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};
    use sx::utils::simple_majority;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl NoExecutionSimpleMajorityExecutionStrategy of IExecutionStrategy<ContractState> {
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
            assert(
                (proposal_status == ProposalStatus::Accepted(()))
                    | (proposal_status == ProposalStatus::VotingPeriodAccepted(())),
                'Invalid Proposal Status'
            );
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
            'NoExecutionSimpleMajority'
        }
    }
}
