#[starknet::contract]
mod NoVotingPowerVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use sx::types::UserAddress;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl NoVotingPowerVotingStrategy of IVotingStrategy<ContractState> {
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            params: Array<felt252>,
            user_params: Array<felt252>,
        ) -> u256 {
            0
        }
    }
}
