#[starknet::contract]
mod OZVotesStorageProofVotingStrategy {
    use starknet::{EthAddress, ContractAddress};
    use sx::external::herodotus::BinarySearchTree;
    use sx::types::{UserAddress, UserAddressTrait};
    use sx::interfaces::IVotingStrategy;
    use sx::utils::{SingleSlotProof, TIntoU256};
    use sx::utils::endian::ByteReverse;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl OZVotesStorageProofVotingStrategy of IVotingStrategy<ContractState> {
        /// Returns the delegated voting power of `voter` at the block number corresponding to `timestamp` for tokens that implement OZVotes.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp of the block at which the voting power is calculated. This will be mapped to an L1 block number by 
        ///   the Herodotus Timestamp Remapper within the SingleSlotProof module call. 
        /// * `voter` - The address of the voter. Expected to be an ethereum address.
        /// * `params` - Should contain the token contract address and the slot index.
        /// * `user_params` - Should contain the index of the final checkpoint in the checkpoints array for `voter` and
        ///   the encoded storage proofs required prove the corresponding slot and the slot after it. 
        ///
        /// # Returns
        ///
        /// `u256` - The voting power of `voter` at the L1 block number corresponding to `timestamp`.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            mut params: Span<felt252>, // [contract_address: address, slot_index: u256]
            mut user_params: Span<
                felt252
            >, // [checkpoint_index: u32, checkpoint_mpt_proof: u64[][], exclusion_mpt_proof: u64[][]]
        ) -> u256 {
            // Cast voter address to an Ethereum address
            // Will revert if the address is not a valid Ethereum address
            let voter = voter.to_ethereum_address();

            // Decode params and user_params
            let (evm_contract_address, slot_index) = Serde::<
                (EthAddress, u256)
            >::deserialize(ref params)
                .unwrap();
            let (checkpoint_index, checkpoint_mpt_proof, exclusion_mpt_proof) = Serde::<
                (u32, Span<Span<u64>>, Span<Span<u64>>)
            >::deserialize(ref user_params)
                .unwrap();

            // Get the slot key for the final checkpoint
            let slot_key = InternalImpl::final_checkpoint_slot_key(
                voter.into(), slot_index, checkpoint_index
            );

            // Get the slot containing the final checkpoint
            // Migration to components planned ; disregard the `unsafe` keyword,
            // it is actually safe.
            let state = SingleSlotProof::unsafe_new_contract_state();
            let checkpoint = SingleSlotProof::InternalImpl::get_storage_slot(
                @state, timestamp, evm_contract_address, slot_key, checkpoint_mpt_proof
            );
            assert(checkpoint.is_non_zero(), 'Slot is zero');

            // Verify the checkpoint is indeed the final checkpoint by checking the next slot is zero.
            assert(
                SingleSlotProof::InternalImpl::get_storage_slot(
                    @state, timestamp, evm_contract_address, slot_key + 1, exclusion_mpt_proof
                )
                    .is_zero(),
                'Invalid Checkpoint'
            );

            // Extract voting power from the encoded checkpoint slot. 
            let (_, vp) = InternalImpl::decode_checkpoint_slot(checkpoint);

            vp
        }
    }

    #[generate_trait]
    impl SingleSlotProofImpl of SingleSlotProofTrait {
        /// Queries the Timestamp Remapper contract for the closest L1 block number that occurred before
        /// the given timestamp and then caches the result. If the queried timestamp is less than the earliest
        /// timestamp or larger than the latest timestamp in the mapper then the transaction will revert.
        /// This function should be used to cache a remapped timestamp before it's used when calling the 
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
        fn final_checkpoint_slot_key(mapping_key: u256, slot_index: u256, offset: u32) -> u256 {
            // Refer to the Solidity compiler documentation for the derivation of this slot key.
            // https://docs.soliditylang.org/en/v0.8.23/internals/layout_in_storage.html#mappings-and-dynamic-arrays
            keccak::keccak_u256s_be_inputs(
                array![
                    keccak::keccak_u256s_be_inputs(array![mapping_key, slot_index].span())
                        .byte_reverse()
                ]
                    .span()
            )
                .byte_reverse()
                + integer::U32IntoU256::into(offset)
        }

        fn decode_checkpoint_slot(slot: u256) -> (u32, u256) {
            // Checkpoints are represented by the following Solidity struct in the token contract:
            // struct Checkpoint {
            //     uint32 fromBlock;
            //     uint224 votes;
            // }
            // This is represented in storage as a single 256 bit slot with the `fromBlock` field
            // stored in the lower 32 bits and the `votes` field stored in the upper 224 bits.
            let block_number = slot.low & 0xffffffff;
            let vp = slot / 0x100000000;
            (block_number.try_into().unwrap(), vp)
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
    use super::OZVotesStorageProofVotingStrategy;

    #[test]
    #[available_gas(10000000)]
    fn get_mapping_slot_key() {
        assert(
            OZVotesStorageProofVotingStrategy::InternalImpl::final_checkpoint_slot_key(
                0x0_u256, 0x0_u256, 0
            ) == u256 {
                low: 0x1e019e72ec816e127a59e7195f2cd7f5, high: 0xf0df3dcda05b4fbd9c655cde3d5ceb21
            },
            'Incorrect slot key'
        );
        assert(
            OZVotesStorageProofVotingStrategy::InternalImpl::final_checkpoint_slot_key(
                0x106b1F88867D99840CaaCAC2dA91265BA6E93e2B_u256, 0x8_u256, 0
            ) == u256 {
                low: 0xe29cc80a3c50310ba7fddc5044149d44, high: 0x87c554e6c4e8f9242420b8d1db45854c
            },
            'Incorrect slot key'
        );
        assert(
            OZVotesStorageProofVotingStrategy::InternalImpl::final_checkpoint_slot_key(
                0x106b1F88867D99840CaaCAC2dA91265BA6E93e2B_u256, 0x8_u256, 4
            ) == u256 {
                low: 0xe29cc80a3c50310ba7fddc5044149d48, high: 0x87c554e6c4e8f9242420b8d1db45854c
            },
            'Incorrect slot key'
        );
    }

    #[test]
    #[available_gas(10000000)]
    fn decode_checkpoint_slot() {
        assert(
            OZVotesStorageProofVotingStrategy::InternalImpl::decode_checkpoint_slot(
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256
            ) == (0xffffffff, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff_u256),
            'Incorrect checkpoint slot'
        );
        assert(
            OZVotesStorageProofVotingStrategy::InternalImpl::decode_checkpoint_slot(
                0x0_u256
            ) == (0, 0),
            'Incorrect checkpoint slot'
        );
        assert(
            OZVotesStorageProofVotingStrategy::InternalImpl::decode_checkpoint_slot(
                0x000000056bc75e2d631f4240009c3685_u256
            ) == (10237573, 100000000000001000000),
            'Incorrect checkpoint slot'
        );
    }
}
