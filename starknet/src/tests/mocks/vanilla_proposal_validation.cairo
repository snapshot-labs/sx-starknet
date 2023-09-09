#[starknet::contract]
mod VanillaProposalValidationStrategy {
    use starknet::ContractAddress;
    use sx::interfaces::IProposalValidationStrategy;
    use sx::types::UserAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl VanillaProposalValidationStrategy of IProposalValidationStrategy<ContractState> {
        /// Vanilla validation strategy that always returns true.
        fn validate(
            self: @ContractState,
            author: UserAddress,
            params: Span<felt252>,
            user_params: Span<felt252>
        ) -> bool {
            true
        }
    }
}
