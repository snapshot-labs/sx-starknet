use sx::utils::types::Proposal;

#[abi]
trait IExecutionStrategy {
    fn execute(proposal: Proposal, votes_for: u256, votes_against: u256, votes_abstain: u256);
}
