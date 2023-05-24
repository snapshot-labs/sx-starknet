use starknet::ContractAddress;

#[abi]
trait IVotingStrategy {
    fn get_voting_power(
        timestamp: u64, voter: ContractAddress, params: Array<u8>, user_params: Array<u8>, 
    ) -> u256;
}

#[contract]
mod VanillaVotingStrategy {
    use starknet::ContractAddress;

    #[external]
    fn get_voting_power(
        timestamp: u64, voter: ContractAddress, params: Array<u8>, user_params: Array<u8>, 
    ) -> u256 {
        u256 { low: 1_u128, high: 0_u128 }
    }
}
