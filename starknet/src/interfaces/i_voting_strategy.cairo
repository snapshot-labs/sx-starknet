use starknet::ContractAddress;

#[starknet::interface]
trait IVotingStrategy<TContractState> {
    fn get_voting_power(
        self: @TContractState,
        timestamp: u64,
        voter: ContractAddress,
        params: Array<felt252>,
        user_params: Array<felt252>,
    ) -> u256;
}
