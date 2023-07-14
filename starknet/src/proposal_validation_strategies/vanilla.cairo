#[starknet::contract]
mod VanillaProposalValidationStrategy {
    use sx::interfaces::IProposalValidationStrategy;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl VanillaProposalValidationStrategy of IProposalValidationStrategy<ContractState> {
        fn validate(
            self: @ContractState,
            author: ContractAddress,
            params: Array<felt252>,
            userParams: Array<felt252>
        ) -> bool {
            true
        }
    }
}
