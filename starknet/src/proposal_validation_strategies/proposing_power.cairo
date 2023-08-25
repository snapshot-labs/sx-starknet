#[starknet::contract]
mod ProposingPowerProposalValidationStrategy {
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
    use sx::utils::proposition_power::_validate;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl ProposingPowerProposalValidationStrategy of IProposalValidationStrategy<ContractState> {
        fn validate(
            self: @ContractState,
            author: UserAddress,
            params: Span<felt252>, // [proposal_threshold: u256, allowed_strategies: Array<Strategy>]
            user_params: Span<felt252> // [user_strategies: Array<IndexedStrategy>]
        ) -> bool {
            _validate(author, params, user_params)
        }
    }
}

