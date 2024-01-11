#[starknet::contract]
mod SingleSlotProof {
    use starknet::{ContractAddress, EthAddress};
    use sx::external::herodotus::{
        Words64, BinarySearchTree, ITimestampRemappersDispatcher,
        ITimestampRemappersDispatcherTrait, IEVMFactsRegistryDispatcher,
        IEVMFactsRegistryDispatcherTrait
    };


    #[storage]
    struct Storage {
        _timestamp_remappers: ContractAddress,
        _facts_registry: ContractAddress,
        _cached_remapped_timestamps: LegacyMap::<u32, u256>
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(
            ref self: ContractState,
            timestamp_remappers: ContractAddress,
            facts_registry: ContractAddress
        ) {
            self._timestamp_remappers.write(timestamp_remappers);
            self._facts_registry.write(facts_registry);
        }

        fn get_storage_slot(
            self: @ContractState,
            timestamp: u32,
            l1_contract_address: EthAddress,
            slot_key: u256,
            mpt_proof: Span<Words64>
        ) -> u256 {
            // Checks if the timestamp is already cached.
            let l1_block_number = self._cached_remapped_timestamps.read(timestamp);
            assert(l1_block_number.is_non_zero(), 'Timestamp not cached');

            // let mut params = params;
            // let mpt_proof = Serde::<Span<Words64>>::deserialize(ref params).unwrap();

            // Computes the key of the EVM storage slot from the mapping key and the index of the mapping in storage.
            // let slot_key = InternalImpl::get_mapping_slot_key(mapping_key, slot_index); // X

            // Returns the value of the storage slot of account: `l1_contract_address` at key: `slot_key` and block number: `l1_block_number`.
            let slot_value = IEVMFactsRegistryDispatcher {
                contract_address: self._facts_registry.read()
            }
                .get_storage(l1_block_number, l1_contract_address.into(), slot_key, mpt_proof);

            assert(slot_value.is_non_zero(), 'Slot is zero');

            slot_value
        }

        fn cache_timestamp(ref self: ContractState, timestamp: u32, tree: BinarySearchTree) {
            // Maps timestamp to closest L1 block number that occured before the timestamp. If the queried 
            // timestamp is less than the earliest timestamp or larger than the latest timestamp in the mapper
            // then the call will return Option::None and the transaction will revert.
            let l1_block_number = ITimestampRemappersDispatcher {
                contract_address: self._timestamp_remappers.read()
            }
                .get_closest_l1_block_number(tree, timestamp.into())
                .expect('TimestampRemappers call failed')
                .expect('Timestamp out of range');

            self._cached_remapped_timestamps.write(timestamp, l1_block_number);
        }

        fn cached_timestamps(self: @ContractState, timestamp: u32) -> u256 {
            let l1_block_number = self._cached_remapped_timestamps.read(timestamp);
            assert(l1_block_number.is_non_zero(), 'Timestamp not cached');
            l1_block_number
        }
    }
}
