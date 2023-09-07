#[starknet::contract]
mod EthBalanceOfVotingStrategy {
    use starknet::{EthAddress, ContractAddress};
    use sx::{
        interfaces::IVotingStrategy, types::{UserAddress, UserAddressTrait},
        utils::single_slot_proof::SingleSlotProof
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl EthBalanceOfVotingStrategy of IVotingStrategy<ContractState> {
        /// Returns the layer 1 balance of the voter. The contract address and slot index is stored
        /// in the strategy parameters (defined by the space owner).
        /// The proof itself is supplied by the voter, in the `user_params` argument.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp of the block at which the voting power is calculated.
        /// * `voter` - The address of the voter.
        /// * `params` - Should contain the contract address and the slot index.
        /// * `user_params` - Should contain the encoded proofs for the L1 contract and the slot index.
        ///
        /// # Returns
        ///
        /// `u256` - The voting power of the voter at the given timestamp.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            params: Span<felt252>, // [contract_address: address, slot_index: u32]
            user_params: Span<felt252>, // encoded proofs
        ) -> u256 {
            // Cast voter address to an Ethereum address
            // Will revert if the address is not an Ethereum address
            let voter = voter.to_ethereum_address();

            // Decode params 
            let contract_address = (*params[0]).into();
            let slot_index = (*params[1]).into();

            // TODO: temporary until components are released
            let state = SingleSlotProof::unsafe_new_contract_state();

            // Get the balance of the voter at the given block timestamp
            let balance = SingleSlotProof::get_storage_slot(
                @state, timestamp, voter.into(), contract_address, slot_index, user_params
            );
            balance
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, facts_registry: ContractAddress, l1_headers_store: ContractAddress
    ) {
        // TODO: temporary until components are released
        let mut state = SingleSlotProof::unsafe_new_contract_state();
        SingleSlotProof::initializer(ref state, facts_registry);
    }
}
