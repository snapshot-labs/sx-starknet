#[starknet::component]
mod SingleSlotProofComponent {
    use starknet::{ContractAddress, EthAddress};
    use sx::external::herodotus::{
        Words64, BinarySearchTree, ITimestampRemappersDispatcher,
        ITimestampRemappersDispatcherTrait, IEVMFactsRegistryDispatcher,
        IEVMFactsRegistryDispatcherTrait
    };

    #[storage]
    struct Storage {
        Singleslotproof_timestamp_remappers: ContractAddress,
        Singleslotproof_facts_registry: ContractAddress,
        Singleslotproof_cached_remapped_timestamps: LegacyMap::<u32, u256>
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            timestamp_remappers: ContractAddress,
            facts_registry: ContractAddress
        ) {
            self.Singleslotproof_timestamp_remappers.write(timestamp_remappers);
            self.Singleslotproof_facts_registry.write(facts_registry);
        }

        fn get_storage_slot(
            self: @ComponentState<TContractState>,
            timestamp: u32,
            l1_contract_address: EthAddress,
            slot_key: u256,
            mpt_proof: Span<Words64>
        ) -> u256 {
            // Checks if the timestamp is already cached.
            let l1_block_number = self.Singleslotproof_cached_remapped_timestamps.read(timestamp);
            assert(l1_block_number.is_non_zero(), 'Timestamp not cached');

            // Returns the value of the storage slot of account: `l1_contract_address` at key: `slot_key` and block number: `l1_block_number`.
            let slot_value = IEVMFactsRegistryDispatcher {
                contract_address: self.Singleslotproof_facts_registry.read()
            }
                .get_storage(l1_block_number, l1_contract_address.into(), slot_key, mpt_proof);

            slot_value
        }

        fn cache_timestamp(
            ref self: ComponentState<TContractState>, timestamp: u32, tree: BinarySearchTree
        ) {
            // Maps timestamp to closest L1 block number that occurred before the timestamp. If the queried 
            // timestamp is less than the earliest timestamp or larger than the latest timestamp in the mapper
            // then the call will return Option::None and the transaction will revert.
            let l1_block_number = ITimestampRemappersDispatcher {
                contract_address: self.Singleslotproof_timestamp_remappers.read()
            }
                .get_closest_l1_block_number(tree, timestamp.into())
                .expect('TimestampRemappers call failed')
                .expect('Timestamp out of range');

            self.Singleslotproof_cached_remapped_timestamps.write(timestamp, l1_block_number);
        }

        fn cached_timestamps(self: @ComponentState<TContractState>, timestamp: u32) -> u256 {
            let l1_block_number = self.Singleslotproof_cached_remapped_timestamps.read(timestamp);
            assert(l1_block_number.is_non_zero(), 'Timestamp not cached');
            l1_block_number
        }
    }
}
