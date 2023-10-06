#[starknet::contract]
mod MerkleWhitelistVotingStrategy {
    use sx::interfaces::IVotingStrategy;
    use sx::types::UserAddress;
    use sx::utils::{merkle, Leaf};

    const LEAF_SIZE: usize = 4; // Serde::<Leaf>::serialize().len()

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MerkleWhitelistImpl of IVotingStrategy<ContractState> {
        /// Returns the voting power of a members of a merkle tree.
        /// The merkle tree root is stored in the strategy parameters (defined by the space owner).
        /// It is up to the user to supply the leaf and the corresponding proof.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - Unused.
        /// * `voter` - The address of the voter. Can be an Ethereum address or a Starknet address.
        /// * `params` - Should contain the merkle tree root.
        /// * `user_params` - Should contain the leaf and the corresponding proof.
        ///
        /// # Returns
        ///
        /// * The voting power of the voter.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            params: Span<felt252>, // [root: felt252]
            user_params: Span<felt252>, // [leaf: Leaf, proof: Array<felt252>]
        ) -> u256 {
            let mut params = params;
            let mut user_params = user_params;

            let root = Serde::<felt252>::deserialize(ref params).unwrap();
            let (leaf, proofs) = Serde::<(Leaf, Array<felt252>)>::deserialize(ref user_params)
                .unwrap();

            assert(leaf.address == voter, 'Leaf and voter mismatch');
            merkle::assert_valid_proof(root, leaf, proofs.span());
            leaf.voting_power
        }
    }
}
