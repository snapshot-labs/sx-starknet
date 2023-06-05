use starknet::ContractAddress;

#[abi]
trait IVotingStrategy {
    #[external]
    fn get_voting_power(
        timestamp: u64, voter: ContractAddress, params: Array<felt252>, user_params: Array<felt252>, 
    ) -> u256;
}
