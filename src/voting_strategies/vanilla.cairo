#[contract]
mod VanillaVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use starknet::ContractAddress;

    #[external]
    fn get_voting_power(
        timestamp: u64, voter: ContractAddress, params: Array<u8>, user_params: Array<u8>, 
    ) -> u256 {
        u256 { low: 1_u128, high: 0_u128 }
    }
}
