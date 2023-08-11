#[starknet::contract]
mod MerkleWhitelistProposalValidationStrategy {
    use sx::interfaces::IProposalValidationStrategy;
    use serde::Serde;
    use sx::types::UserAddress;
    use array::{ArrayTrait, Span, SpanTrait};
    use option::OptionTrait;
    use sx::utils::merkle::{assert_valid_proof, Leaf};
    use debug::PrintTrait;

    const LEAF_SIZE: usize = 4; // Serde::<Leaf>::serialize().len()

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MerkleWhitelistImpl of IProposalValidationStrategy<ContractState> {
        fn validate(
            self: @ContractState,
            author: UserAddress,
            params: Array<felt252>, // [root, threshold]
            user_params: Array<felt252> // [Serde(leaf), Serde(proofs)]
        ) -> bool {
            let cache = user_params.span(); // cache

            let mut leaf_raw = cache.slice(0, LEAF_SIZE);
            let leaf = Serde::<Leaf>::deserialize(ref leaf_raw).unwrap();

            let mut proofs_raw = cache.slice(LEAF_SIZE, cache.len() - LEAF_SIZE);
            let proofs = Serde::<Array<felt252>>::deserialize(ref proofs_raw).unwrap();

            let mut sp4n = params.span();
            let (root, threshold) = Serde::<(felt252, u256)>::deserialize(ref sp4n).unwrap();

            assert_valid_proof(root, leaf, proofs.span());
            leaf.voting_power >= threshold
        }
    }
}
