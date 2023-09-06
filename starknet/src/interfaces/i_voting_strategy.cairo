use starknet::ContractAddress;
use sx::types::UserAddress;

#[starknet::interface]
trait IVotingStrategy<TContractState> {
    /// 
    ///
    /// # Arguments
    ///
    /// * `timestamp` - The timestamp to use to compute the voting power.
    /// * `voter` - The address of the voter.
    /// * `params` - The strategy-supplied parameters used to compute the voting power.
    /// * `user_params` - The user-supplied parameters used to compute the voting power.
    ///
    /// # Returns
    ///
    /// * `u256` - The voting power of the voter.
    fn get_voting_power(
        self: @TContractState,
        timestamp: u32,
        voter: UserAddress,
        params: Span<felt252>,
        user_params: Span<felt252>,
    ) -> u256;
}
