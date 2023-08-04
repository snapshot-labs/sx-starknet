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
            params: Array<felt252>,
            userParams: Array<felt252>
        ) -> bool {
            true
        }
    }
}
