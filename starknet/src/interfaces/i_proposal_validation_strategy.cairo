use starknet::ContractAddress;

#[starknet::interface]
trait IProposalValidationStrategy<TContractState> {
    fn validate(
        self: @TContractState,
        author: ContractAddress,
        params: Array<felt252>,
        userParams: Array<felt252>
    ) -> bool;
}
