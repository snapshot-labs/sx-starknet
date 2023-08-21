use starknet::ContractAddress;
use sx::types::UserAddress;

#[starknet::interface]
trait IProposalValidationStrategy<TContractState> {
    fn validate(
        self: @TContractState,
        author: UserAddress,
        params: Array<felt252>,
        user_params: Array<felt252>
    ) -> bool;
}
