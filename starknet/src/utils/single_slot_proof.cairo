#[starknet::contract]
mod SingleSlotProof {
    use starknet::{ContractAddress, EthAddress};
    use sx::external::herodotus::{
        Words64, BinarySearchTree, ITimestampRemappersDispatcher,
        ITimestampRemappersDispatcherTrait, IEVMFactsRegistryDispatcher,
        IEVMFactsRegistryDispatcherTrait
    };
    use sx::utils::endian::ByteReverse;

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
            slot_index: u256,
            mapping_key: u256,
            params: Span<felt252>
        ) -> u256 {
            // Checks if the timestamp is already cached.
            let l1_block_number = self._cached_remapped_timestamps.read(timestamp);
            assert(l1_block_number.is_non_zero(), 'Timestamp not cached');

            let mut params = params;
            let mpt_proof = Serde::<Span<Words64>>::deserialize(ref params).unwrap();

            // Computes the key of the EVM storage slot from the mapping key and the index of the mapping in storage.
            let slot_key = InternalImpl::get_mapping_slot_key(mapping_key, slot_index);

            // Returns the value of the storage slot of account: `l1_contract_address` at key: `slot_key` and block number: `l1_block_number`.
            let slot_value = IEVMFactsRegistryDispatcher {
                contract_address: self._facts_registry.read()
            }
                .get_storage(l1_block_number, l1_contract_address.into(), slot_key, mpt_proof);

            assert(slot_value.is_non_zero(), 'Slot is zero');

            slot_value
        }

        fn get_mapping_slot_key(mapping_key: u256, slot_index: u256) -> u256 {
            keccak::keccak_u256s_be_inputs(array![mapping_key, slot_index].span()).byte_reverse()
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

#[cfg(test)]
mod tests {
    use core::clone::Clone;
    use super::SingleSlotProof;
    use debug::PrintTrait;

    type Words64 = Span<u64>;

    #[test]
    #[available_gas(10000000)]
    fn get_mapping_slot_key() {
        let proof = array![
            array![
                0x5c0b6aa0808051f8,
                0x9720a2845ec292e7,
                0xdde909402854fc40,
                0x8b0ff9103babb578,
                0x808080c17ea1cc35,
                0xf86ba08080808080,
                0x652dee110f0a9fd1,
                0x98195bc1e2e398a8,
                0xcb959918a8d08b95,
                0x8080d2e4ec07dcfc,
                0x808080
            ]
                .span(),
            array![
                0x76522d0e31a043f8,
                0x71fdcdee263b0712,
                0xfa4a4bf40c326a7e,
                0xb7e2cb9f2d73b0c2,
                0x636f4da0a1f60cfa,
                0x000000000000006b,
                0x0000000000000000,
                0x0000000000000000,
                0x0800000000
            ]
                .span()
        ];

        let mut serial = array![];
        proof.serialize(ref serial);
        serial.clone().print();

        let mut params = serial.span();
        let mpt_proof = Serde::<Span<Words64>>::deserialize(ref params).unwrap();
        let mut serial2 = array![];
        mpt_proof.serialize(ref serial2);
        serial2.print();

        assert(
            SingleSlotProof::InternalImpl::get_mapping_slot_key(
                0x0_u256, 0x0_u256
            ) == u256 {
                low: 0x2b36e491b30a40b2405849e597ba5fb5, high: 0xad3228b676f7d3cd4284a5443f17f196
            },
            'Incorrect slot key'
        );
        assert(
            SingleSlotProof::InternalImpl::get_mapping_slot_key(
                0x1_u256, 0x0_u256
            ) == u256 {
                low: 0x10426056ef8ca54750cb9bb552a59e7d, high: 0xada5013122d395ba3c54772283fb069b
            },
            'Incorrect slot key'
        );
        assert(
            SingleSlotProof::InternalImpl::get_mapping_slot_key(
                0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045_u256, 0x1_u256
            ) == u256 {
                low: 0xad9172e102b3af1e07a10cc29003beb2, high: 0xb931be0b3d1fb06daf0d92e2b8dfe49e
            },
            'Incorrect slot key'
        );
    }
}

