#[starknet::contract]
mod AlwaysFailProposalValidationStrategy {
    use starknet::ContractAddress;
    use sx::types::UserAddress;
    use sx::interfaces::{IProposalValidationStrategy,};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl AlwaysFailProposalValidationStrategy of IProposalValidationStrategy<ContractState> {
        fn validate(
            self: @ContractState,
            author: UserAddress,
            params: Span<felt252>,
            user_params: Span<felt252>
        ) -> bool {
            false
        }
    }
}
