#[contract]
mod AlwaysFailProposalValidationStrategy {
    use starknet::ContractAddress;

    #[external]
    fn validate(author: ContractAddress, params: Array<u8>, userParams: Array<u8>) -> bool {
        false
    }
}
