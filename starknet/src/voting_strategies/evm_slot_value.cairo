#[starknet::contract]
mod EvmSlotValueVotingStrategy {
    use starknet::{EthAddress, ContractAddress};
    use sx::external::herodotus::BinarySearchTree;
    use sx::types::{UserAddress, UserAddressTrait};
    use sx::interfaces::IVotingStrategy;
    use sx::utils::{SingleSlotProof, TIntoU256};
    use sx::utils::endian::ByteReverse;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl EvmSlotValueVotingStrategy of IVotingStrategy<ContractState> {
        /// Returns the value of a slot in a mapping in an EVM contract at the block number corresponding to the given timestamp.
        ///
        /// # Notes
        ///
        /// This is most often used for proving a user balance on a different chain, such as a ERC20 token balance on L1.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp of the block at which the voting power is calculated.
        /// * `voter` - The address of the voter. Expected to be an ethereum address.
        /// * `params` - Should contain the contract address and the slot index.
        /// * `user_params` - Should contain the encoded proofs for the L1 contract and the slot index.
        ///
        /// # Returns
        ///
        /// `u256` - The slot value of the voter at the given timestamp.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            mut params: Span<felt252>, // [contract_address: address, slot_index: u256]
            mut user_params: Span<felt252>, // [mpt_proof: u64[][]]
        ) -> u256 {
            // Cast voter address to an Ethereum address
            // Will revert if the address is not a valid Ethereum address
            let voter = voter.to_ethereum_address();

            // Decode params and user_params
            let (evm_contract_address, slot_index) = Serde::<
                (EthAddress, u256)
            >::deserialize(ref params)
                .unwrap();
            let mpt_proof = Serde::<Span<Span<u64>>>::deserialize(ref user_params).unwrap();

            // Computes the key of the EVM storage slot from the mapping key and the index of the mapping in storage.
            let slot_key = InternalImpl::get_mapping_slot_key(voter.into(), slot_index);

            // Returns the value of the storage slot at the block number corresponding to the given timestamp.
            // Migration to components planned ; disregard the `unsafe` keyword,
            // it is actually safe.
            let state = SingleSlotProof::unsafe_new_contract_state();
            let slot_value = SingleSlotProof::InternalImpl::get_storage_slot(
                @state, timestamp, evm_contract_address, slot_key, mpt_proof
            );
            assert(slot_value.is_non_zero(), 'Slot is zero');

            slot_value
        }
    }

    #[generate_trait]
    impl SingleSlotProofImpl of SingleSlotProofTrait {
        /// Queries the Timestamp Remapper contract for the closest L1 block number that occured before
        /// the given timestamp and then caches the result. If the queried timestamp is less than the earliest
        /// timestamp or larger than the latest timestamp in the mapper then the transaction will revert.
        /// This function should be used to cache a remapped timestamp before its used when calling the 
        /// `get_storage_slot` function with the same timestamp.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp at which to query.
        /// * `tree` - The tree proof required to query the remapper.
        fn cache_timestamp(ref self: ContractState, timestamp: u32, tree: BinarySearchTree) {
            let mut state = SingleSlotProof::unsafe_new_contract_state();
            SingleSlotProof::InternalImpl::cache_timestamp(ref state, timestamp, tree);
        }

        /// View function exposing the cached remapped timestamps. Reverts if the timestamp is not cached.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp to query.
        /// 
        /// # Returns
        ///
        /// * `u256` - The cached L1 block number corresponding to the timestamp.
        fn cached_timestamps(self: @ContractState, timestamp: u32) -> u256 {
            let state = SingleSlotProof::unsafe_new_contract_state();
            SingleSlotProof::InternalImpl::cached_timestamps(@state, timestamp)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_mapping_slot_key(mapping_key: u256, slot_index: u256) -> u256 {
            keccak::keccak_u256s_be_inputs(array![mapping_key, slot_index].span()).byte_reverse()
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        timestamp_remappers: ContractAddress,
        facts_registry: ContractAddress
    ) {
        // Migration to components planned ; disregard the `unsafe` keyword,
        // it is actually safe.
        let mut state = SingleSlotProof::unsafe_new_contract_state();
        SingleSlotProof::InternalImpl::initializer(ref state, timestamp_remappers, facts_registry);
    }
}

#[cfg(test)]
mod tests {
    use super::EvmSlotValueVotingStrategy;

    #[test]
    #[available_gas(10000000)]
    fn get_mapping_slot_key() {
        assert(
            EvmSlotValueVotingStrategy::InternalImpl::get_mapping_slot_key(
                0x0_u256, 0x0_u256
            ) == u256 {
                low: 0x2b36e491b30a40b2405849e597ba5fb5, high: 0xad3228b676f7d3cd4284a5443f17f196
            },
            'Incorrect slot key'
        );
        assert(
            EvmSlotValueVotingStrategy::InternalImpl::get_mapping_slot_key(
                0x1_u256, 0x0_u256
            ) == u256 {
                low: 0x10426056ef8ca54750cb9bb552a59e7d, high: 0xada5013122d395ba3c54772283fb069b
            },
            'Incorrect slot key'
        );
        assert(
            EvmSlotValueVotingStrategy::InternalImpl::get_mapping_slot_key(
                0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045_u256, 0x1_u256
            ) == u256 {
                low: 0xad9172e102b3af1e07a10cc29003beb2, high: 0xb931be0b3d1fb06daf0d92e2b8dfe49e
            },
            'Incorrect slot key'
        );
    }
}
