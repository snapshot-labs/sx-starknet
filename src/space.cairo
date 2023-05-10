use starknet::ContractAddress;
use array::ArrayTrait;

struct Strategy {
    address: ContractAddress,
    params: Array<u8>,
}

trait ISpace {
    fn max_voting_duration() -> u256;
    fn min_voting_duration() -> u256;
    fn next_proposal_id() -> u256;
    fn voting_delay() -> u256;
    fn authenticators(account: ContractAddress) -> bool;
    fn voting_strategies(index: u8) -> Strategy;
    fn active_voting_strategies() -> u256;
    fn next_voting_strategy_index() -> u8;
    fn proposal_validation_strategy() -> Strategy;
    fn vote_power(proposal_id: u256, choice: u8) -> u256;
    fn vote_registry(proposal_id: u256, voter: ContractAddress) -> bool;
    fn proposals(proposal_id: u256) -> (u32, u32, u32, u32, u32, ContractAddress, ContractAddress, u8, u256);
    fn get_proposal_status(proposal_id: u256) -> u8;
}

#[contract]
mod ERC20 {
    use super::ISpace;
}