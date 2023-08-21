use sx::interfaces::IProposalValidationStrategy;
use sx::types::{UserAddress, IndexedStrategy, IndexedStrategyTrait, Strategy};
use sx::interfaces::{IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait};
use starknet::ContractAddress;
use starknet::info;
use traits::{Into, TryInto};
use option::OptionTrait;
use result::ResultTrait;
use array::{ArrayTrait, SpanTrait};
use serde::Serde;
use sx::utils::bits::BitSetter;
use box::BoxTrait;
use clone::Clone;

fn _get_cumulative_power(
    voter: UserAddress,
    timestamp: u32,
    mut user_strategies: Array<IndexedStrategy>,
    allowed_strategies: Array<Strategy>,
) -> u256 {
    user_strategies.assert_no_duplicate_indices();
    let mut total_voting_power = 0_u256;
    loop {
        match user_strategies.pop_front() {
            Option::Some(indexed_strategy) => {
                match allowed_strategies.get(indexed_strategy.index.into()) {
                    Option::Some(strategy) => {
                        let strategy: Strategy = strategy.unbox().clone();
                        total_voting_power += IVotingStrategyDispatcher {
                            contract_address: strategy.address
                        }
                            .get_voting_power(
                                timestamp, voter, strategy.params, indexed_strategy.params, 
                            );
                    },
                    Option::None => {
                        panic_with_felt252('Invalid strategy index');
                    },
                };
            },
            Option::None => {
                break total_voting_power;
            },
        };
    }
}

fn _validate(
    author: UserAddress,
    params: Array<felt252>, // [proposal_threshold: u256, allowed_strategies: Array<Strategy>]
    user_params: Array<felt252> // [user_strategies: Array<IndexedStrategy>]
) -> bool {
    let mut params_span = params.span();
    let (proposal_threshold, allowed_strategies) = Serde::<(
        u256, Array<Strategy>
    )>::deserialize(ref params_span)
        .unwrap();

    let mut user_params_span = user_params.span();
    let user_strategies = Serde::<Array<IndexedStrategy>>::deserialize(ref user_params_span)
        .unwrap();

    let timestamp: u32 = info::get_block_timestamp().try_into().unwrap();
    let voting_power = _get_cumulative_power(
        author, timestamp, user_strategies, allowed_strategies
    );
    voting_power >= proposal_threshold
}

