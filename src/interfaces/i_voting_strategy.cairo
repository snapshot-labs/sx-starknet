use starknet::ContractAddress;

#[abi]
trait IVotingStrategy {
    fn get_voting_power(
        timestamp: u64, voter: ContractAddress, params: Array<u8>, user_params: Array<u8>, 
    ) -> u256;
}
