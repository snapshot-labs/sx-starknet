#[starknet::contract]
mod ERC20VotesVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use sx::types::{UserAddress, UserAddressTrait};
    use starknet::ContractAddress;
    use openzeppelin::governance::utils::interfaces::votes::{
        IVotes, IVotesDispatcher, IVotesDispatcherTrait
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl ERC20VotesVotingStrategy of IVotingStrategy<ContractState> {
        /// Returns the total amount of delegated votes of `voter` at the given `timestamp`.
        /// A user must self-delegate if he wishes to have voting power.
        /// This is *not* the user's token balance, but the users's delegated voting power!
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp at which to calculate the voting power.
        /// * `voter` - The address of the voter. Expected to be a starknet address.
        /// * `params` - Expected to hold the address of the ERC20 contract.
        /// * `_user_params` - Unused.
        ///
        /// # Returns
        ///
        /// * `u256` - The voting power of the voter at the given timestamp.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            mut params: Span<felt252>, // [contract_address: address]
            user_params: Span<felt252>,
        ) -> u256 {
            // Cast voter address to a Starknet address
            // Will revert if the address is not a Starknet address
            let voter = voter.to_starknet_address();

            // Get the ERC20 contract address from the params array
            let erc20_contract_address = Serde::<ContractAddress>::deserialize(ref params).unwrap();

            let erc20 = IVotesDispatcher { contract_address: erc20_contract_address, };

            erc20.get_past_votes(voter, timestamp.into())
        }
    }
}
