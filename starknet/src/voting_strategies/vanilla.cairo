#[starknet::contract]
mod VanillaVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use sx::types::UserAddress;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl VanillaVotingStrategy of IVotingStrategy<ContractState> {
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
