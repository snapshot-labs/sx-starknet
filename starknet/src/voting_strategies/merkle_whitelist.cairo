#[starknet::contract]
mod MerkleWhitelistVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use serde::Serde;
    use sx::types::UserAddress;
    use array::{ArrayTrait, Span, SpanTrait};
    use option::OptionTrait;
    use sx::utils::merkle::{assert_valid_proof, Leaf};
    use debug::PrintTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MerkleWhitelistImpl of IVotingStrategy<ContractState> {
        fn get_voting_power(
            self: @ContractState,
            block_number: u32,
            voter: UserAddress,
            params: Array<felt252>, // [root]
            user_params: Array<felt252>, // [Serde(leaf), Serde(proofs)]
        ) -> u256 {
            let LEAF_SIZE = 4; // Serde::<Leaf>::serialize().len()
            let cache = user_params.span(); // cache

            let mut leaf_raw = cache.slice(0, LEAF_SIZE);
            let leaf = Serde::<Leaf>::deserialize(ref leaf_raw).unwrap();

            let mut proofs_raw = cache.slice(LEAF_SIZE, cache.len() - LEAF_SIZE);
            let proofs = Serde::<Array<felt252>>::deserialize(ref proofs_raw).unwrap();

            let root = *params.at(0); // no need to deserialize because it's a simple value

            assert_valid_proof(root, leaf, proofs.span());
            leaf.voting_power
        }
    }
}
