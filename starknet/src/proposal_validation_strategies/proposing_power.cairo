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
        /// Designed to be used by spaces that which to use voting strategies to define who can create proposals.
        /// The allowed strategies simply need to be supplied in the `params` field.
        ///
        /// # Arguments
        ///
        /// * `author` - The address of the proposal author.
        /// * `params` - The strategy-supplied parameters (defined by space owner) used to compute the proposing power.
        ///              The encoded parameters should be: [proposal_threshold: u256, allowed_strategies: Array<Strategy>]
        /// * `user_params` - The user-supplied parameters of the proposal used to compute the proposing power.
        ///                   The encoded parameters should be: [user_strategies: Array<IndexedStrategy>]
        ///
        /// # Returns
        ///
        /// * `true` if the user has enough proposing power ; `false` otherwise.
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

