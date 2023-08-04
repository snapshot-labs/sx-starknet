#[starknet::contract]
mod AlwaysFailProposalValidationStrategy {
    use starknet::ContractAddress;
    use sx::types::UserAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    #[generate_trait]
    impl AlwaysFailProposalValidationStrategy of IAlwaysFailProposalValidationStrategy {
        fn validate(
            self: @ContractState,
            author: UserAddress,
            params: Array<felt252>,
            userParams: Array<felt252>
        ) -> bool {
            false
        }
    }
}
