#[starknet::contract]
mod VanillaProposalValidationStrategy {
    use sx::interfaces::IProposalValidationStrategy;
    use sx::types::UserAddress;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl VanillaProposalValidationStrategy of IProposalValidationStrategy<ContractState> {
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
