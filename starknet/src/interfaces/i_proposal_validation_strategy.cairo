use starknet::ContractAddress;

#[abi]
trait IProposalValidationStrategy {
    #[external]
    fn validate(
        author: ContractAddress, params: Array<felt252>, userParams: Array<felt252>
    ) -> bool;
}
