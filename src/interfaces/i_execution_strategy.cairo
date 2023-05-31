use array::ArrayTrait;
use sx::utils::types::Proposal;

#[abi]
trait IExecutionStrategy {
    #[external]
    fn execute(
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<u8>
    );
}
