#[starknet::contract]
mod AlwaysFailProposalValidationStrategy {
    use starknet::ContractAddress;
    use sx::types::UserAddress;

    #[storage]
    struct Storage {}

    #[generate_trait]
    impl AlwaysFailProposalValidationStrategy of IAlwaysFailProposalValidationStrategy {
        fn validate(
            self: @ContractState,
            author: UserAddress,
            params: Span<felt252>,
            user_params: Span<felt252>
        ) -> bool {
            false
        }
    }
}
