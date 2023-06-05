#[contract]
mod VanillaProposalValidationStrategy {
    use sx::interfaces::IProposalValidationStrategy;
    use starknet::ContractAddress;

    impl VanillaProposalValidationStrategy of IProposalValidationStrategy {
        fn validate(
            author: ContractAddress, params: Array<felt252>, userParams: Array<felt252>
        ) -> bool {
            true
        }
    }

    #[external]
    fn validate(
        author: ContractAddress, params: Array<felt252>, userParams: Array<felt252>
    ) -> bool {
        VanillaProposalValidationStrategy::validate(author, params, userParams)
    }
}
