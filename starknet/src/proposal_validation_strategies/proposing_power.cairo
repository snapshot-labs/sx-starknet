#[starknet::contract]
mod ProposingPowerProposalValidationStrategy {
    use sx::{
        interfaces::{
            IProposalValidationStrategy, IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait
        },
        types::{UserAddress, IndexedStrategy, IndexedStrategyTrait, Strategy},
        utils::{bits::BitSetter, proposition_power::_validate}
    };
    use starknet::{ContractAddress, info};

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

