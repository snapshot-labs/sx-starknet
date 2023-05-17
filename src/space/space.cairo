use starknet::ContractAddress;
use sx::utils::types::Strategy;

#[abi]
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
    fn proposals(proposal_id: u256) -> ContractAddress;
    fn get_proposal_status(proposal_id: u256) -> u8;
}

#[contract]
mod Space {
    use super::ISpace;
    use starknet::ContractAddress;
    use sx::utils::types::{Strategy};
    use zeroable::Zeroable;
    use array::{ArrayTrait, SpanTrait};
    use sx::utils::bits::{BitSetter}; // idiomatic imports? 
    use clone::Clone;
    use core::option::OptionTrait;


    struct Storage {
        _owner: ContractAddress,
        _max_voting_duration: u256,
        _min_voting_duration: u256,
        _next_proposal_id: u256,
        _voting_delay: u256,
        _active_voting_strategies: u256,
        _voting_strategies: LegacyMap::<u8, Strategy>,
        _next_voting_strategy_index: u8,
        _proposal_validation_strategy: Strategy,
        _authenticators: LegacyMap::<ContractAddress, bool>,
        _proposals: LegacyMap::<u256, ContractAddress>, // TODO proposal struct
        _vote_power: LegacyMap::<(u256, u8), u256>, // TODO choice enum
        _vote_registry: LegacyMap::<(u256, ContractAddress), bool>,
    }

    #[constructor]
    fn constructor(
        _owner: ContractAddress,
        _max_voting_duration: u256,
        _min_voting_duration: u256,
        _voting_delay: u256,
        _proposal_validation_strategy: Strategy,
        _voting_strategies: Array<Strategy>,
        _authenticators: Array<ContractAddress>,
    ) {
        _owner::write(_owner);
        _set_max_voting_duration(_max_voting_duration);
        _set_min_voting_duration(_min_voting_duration);
        _set_voting_delay(_voting_delay);
        _set_proposal_validation_strategy(_proposal_validation_strategy);
        _add_voting_strategies(_voting_strategies);
        _add_authenticators(_authenticators);
        _next_proposal_id::write(u256 { low: 1_u128, high: 0_u128 }); // Maybe easier way to do this?
    }

    #[view]
    fn owner() -> ContractAddress {
        _owner::read()
    }

    #[view]
    fn max_voting_duration() -> u256 {
        _max_voting_duration::read()
    }

    #[view]
    fn min_voting_duration() -> u256 {
        _min_voting_duration::read()
    }

    #[view]
    fn next_proposal_id() -> u256 {
        _next_proposal_id::read()
    }

    #[view]
    fn voting_delay() -> u256 {
        _voting_delay::read()
    }

    // TODO: wont compile
    #[view]
    fn proposal_validation_strategy() -> Strategy {
        _proposal_validation_strategy::read()
    }

    /// 
    /// Internals
    ///

    fn _set_max_voting_duration(_max_voting_duration: u256) {
        _max_voting_duration::write(_max_voting_duration);
    }

    fn _set_min_voting_duration(_min_voting_duration: u256) {
        _min_voting_duration::write(_min_voting_duration);
    }

    fn _set_voting_delay(_voting_delay: u256) {
        _voting_delay::write(_voting_delay);
    }

    fn _set_proposal_validation_strategy(_proposal_validation_strategy: Strategy) {
        _proposal_validation_strategy::write(_proposal_validation_strategy);
    }

    fn _add_voting_strategies(_voting_strategies: Array<Strategy>) {
        // TODO: checks
        let mut cachedActiveVotingStrategies = _active_voting_strategies::read();
        let mut cachedNextVotingStrategyIndex = _next_voting_strategy_index::read();

        let mut _voting_strategies_span = _voting_strategies.span();
        let mut i = 0_usize;
        loop {
            if i >= _voting_strategies.len() {
                break ();
            }

            let strategy = _voting_strategies_span.pop_front().unwrap().clone();
            assert(strategy.address.is_zero(), 'Invalid voting strategy');
            cachedActiveVotingStrategies.set_bit(cachedNextVotingStrategyIndex, true);
            _voting_strategies::write(cachedNextVotingStrategyIndex, strategy);
            cachedNextVotingStrategyIndex += 1_u8;
            i += 1;
        };
        _active_voting_strategies::write(cachedActiveVotingStrategies);
        _next_voting_strategy_index::write(cachedNextVotingStrategyIndex);
    }
    // TODO: need to impl set_bit to false first
    // fn _remove_voting_strategies(_voting_strategies: Array<Strategy>) {
    //     let index = next_voting_strategy_index::read();
    //     voting_strategies::write(index, _voting_strategy);
    //     next_voting_strategy_index::write(index + 1_u8);
    // }

    fn _add_authenticators(_authenticators: Array<ContractAddress>) {
        let mut _authenticators_span = _authenticators.span();
        let mut i = 0_usize;
        loop {
            if i >= _authenticators.len() {
                break ();
            }
            _authenticators::write(*_authenticators_span.pop_front().unwrap(), true);
            i += 1;
        }
    }

    fn _remove_authenticators(_authenticators: Array<ContractAddress>) {
        let mut _authenticators_span = _authenticators.span();
        let mut i = 0_usize;
        loop {
            if i >= _authenticators.len() {
                break ();
            }
            _authenticators::write(*_authenticators_span.pop_front().unwrap(), false);
            i += 1;
        }
    }
}

