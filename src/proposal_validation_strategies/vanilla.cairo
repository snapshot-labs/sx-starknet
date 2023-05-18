#[contract]
mod VanillaProposalValidationStrategy {
    use starknet::ContractAddress;

    #[external]
    fn validate(author: ContractAddress, params: Array<u8>) -> bool {
        true
    }
}
