#[starknet::contract]
mod VanillaVotingStrategy {
    use starknet::ContractAddress;
    use sx::{interfaces::IVotingStrategy, types::UserAddress};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl VanillaVotingStrategy of IVotingStrategy<ContractState> {
        /// Vanilla voting strategy that returns 1 for all voters.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            params: Span<felt252>,
            user_params: Span<felt252>,
        ) -> u256 {
            1_u256
        }
    }
}
