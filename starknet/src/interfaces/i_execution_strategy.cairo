use array::ArrayTrait;
use sx::types::Proposal;

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

    fn get_strategy_type(self: @TContractState) -> felt252;
}
