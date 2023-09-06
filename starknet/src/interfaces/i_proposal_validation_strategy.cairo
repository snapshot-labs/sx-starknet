use starknet::ContractAddress;
use sx::types::UserAddress;

#[starknet::interface]
trait IProposalValidationStrategy<TContractState> {
    /// Validates whether `author` has the right to create a new proposal or not.
    /// # Arguments
    /// 
    /// * `author` - The address of the proposal author.
    /// * `params` - Strategy-supplied parameters, stored in the space contract and defined by the space owner.
    /// * `user_params` - User-supplied parameters.
    ///
    /// # Returns
    /// 
    /// * `bool` - `true` if `author` has the right to create a new proposal. `false` otherwise.
    fn validate(
        self: @TContractState,
        author: UserAddress,
        params: Span<felt252>,
        user_params: Span<felt252>
    ) -> bool;
}
