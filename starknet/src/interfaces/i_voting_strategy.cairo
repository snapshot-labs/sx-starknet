use starknet::ContractAddress;
use sx::types::UserAddress;

#[starknet::interface]
trait IVotingStrategy<TContractState> {
    fn get_voting_power(
        self: @TContractState,
        timestamp: u32,
        voter: UserAddress,
        params: Span<felt252>,
        user_params: Span<felt252>,
    ) -> u256;
}
