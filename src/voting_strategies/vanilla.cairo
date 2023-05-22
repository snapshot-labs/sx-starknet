use starknet::ContractAddress;
use sx::utils::types::Proposal;

#[abi]
trait IVotingStrategy {
    fn getVotingPower(
        timestamp: u64, voter: ContractAddress, params: Array<u8>, user_params: Array<u8>, 
    ) -> u256;
}

#[contract]
mod VanillaVotingStrategy {
    use starknet::ContractAddress;
    use sx::utils::types::Proposal;

    #[external]
    fn getVotingPower(
        timestamp: u64, voter: ContractAddress, params: Array<u8>, user_params: Array<u8>, 
    ) -> u256 {
        return u256 { low: 1_u128, high: 0_u128 };
    }
}
