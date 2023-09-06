use sx::types::{Proposal, ProposalStatus};

/// The execution strategy interface that all execution strategies must implement.
#[starknet::interface]
trait IExecutionStrategy<TContractState> {
    /// Entrypoint to execute the proposal.
    /// It is up to the `execute` function to perform the necessary
    /// checks to ensure that the proposal should be executed.
    fn execute(
        ref self: TContractState,
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<felt252>
    );

    /// View function to get the proposal status.
    fn get_proposal_status(
        self: @TContractState,
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
    ) -> ProposalStatus;

    /// Returns a short string describing the strategy type.
    fn get_strategy_type(self: @TContractState) -> felt252;
}
