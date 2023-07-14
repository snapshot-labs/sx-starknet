#[starknet::contract]
mod AlwaysFailProposalValidationStrategy {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    #[generate_trait]
    impl AlwaysFailProposalValidationStrategy of IAlwaysFailProposalValidationStrategy {
        fn validate(
            self: @ContractState,
            author: ContractAddress,
            params: Array<felt252>,
            userParams: Array<felt252>
        ) -> bool {
            false
        }
    }
}
