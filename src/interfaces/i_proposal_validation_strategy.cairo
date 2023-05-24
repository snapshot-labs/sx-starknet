use starknet::ContractAddress;

#[abi]
trait IProposalValidationStrategy {
    fn validate(author: ContractAddress, params: Array<u8>, userParams: Array<u8>) -> bool;
}
