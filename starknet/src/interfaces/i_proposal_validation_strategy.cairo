use starknet::ContractAddress;
use sx::types::UserAddress;

#[starknet::interface]
trait IProposalValidationStrategy<TContractState> {
    fn validate(
        self: @TContractState,
        author: UserAddress,
        params: Span<felt252>,
        user_params: Span<felt252>
    ) -> bool;
}
