use array::ArrayTrait;
use sx::utils::sx_types::Proposal;

#[starknet::interface]
trait IExecutionStrategy<TContractState> {
    fn execute(
        ref self: TContractState,
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<felt252>
    );
}
