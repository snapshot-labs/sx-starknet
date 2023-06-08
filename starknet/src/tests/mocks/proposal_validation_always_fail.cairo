#[contract]
mod AlwaysFailProposalValidationStrategy {
    use starknet::ContractAddress;

    #[external]
    fn validate(
        author: ContractAddress, params: Array<felt252>, userParams: Array<felt252>
    ) -> bool {
        false
    }
}
