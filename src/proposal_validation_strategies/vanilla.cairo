#[contract]
mod VanillaProposalValidationStrategy {
    use sx::interfaces::IProposalValidationStrategy;
    use starknet::ContractAddress;

    impl VanillaProposalValidationStrategy of IProposalValidationStrategy {
        #[external]
        fn validate(author: ContractAddress, params: Array<u8>, userParams: Array<u8>) -> bool {
            true
        }
    }
}
