#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    fn get_closest_l1_block_number(
        self: @TContractState, tree: BinarySearchTree, timestamp: u256
    ) -> Option<u256>;
}

#[starknet::interface]
trait IEVMFactsRegistry<TContractState> {
    fn get_slot_value(self: @TContractState, account: felt252, block: u256, slot: u256) -> u256;
}

type Peaks = Span<felt252>;

type Proof = Span<felt252>;

#[derive(Drop, Copy, Serde)]
struct ProofElement {
    index: usize,
    value: u256,
    peaks: Peaks,
    proof: Proof,
    last_pos: usize,
}

#[derive(Drop, Copy, Serde)]
struct BinarySearchTree {
    mapper_id: usize,
    mmr_id: usize,
    proofs: Span<ProofElement>,
    left_neighbor: Option<ProofElement>,
}


#[starknet::contract]
mod SingleSlotProof {
    use starknet::{ContractAddress, EthAddress};
    use zeroable::Zeroable;
    use integer::u128_byte_reverse;
    use array::ArrayTrait;
    use serde::Serde;
    use option::OptionTrait;
    use traits::{Into, TryInto};
    use super::{
        ProofElement, BinarySearchTree, ITimestampRemappers, ITimestampRemappersDispatcher,
        ITimestampRemappersDispatcherTrait, IEVMFactsRegistry, IEVMFactsRegistryDispatcher,
        IEVMFactsRegistryDispatcherTrait
    };
    use sx::utils::{math};

    #[storage]
    struct Storage {
        _timestamp_remappers: ContractAddress,
        _facts_registry: ContractAddress
    }

    #[internal]
    fn initializer(
        ref self: ContractState,
        timestamp_remappers: ContractAddress,
        facts_registry: ContractAddress
    ) {
        self._timestamp_remappers.write(timestamp_remappers);
        self._facts_registry.write(facts_registry);
    }

    trait ByteReverse<T> {
        fn byte_reverse(self: T) -> T;
    }

    impl ByteReverseU256 of ByteReverse<u256> {
        fn byte_reverse(self: u256) -> u256 {
            u256 { low: u128_byte_reverse(self.high), high: u128_byte_reverse(self.low) }
        }
    }

    #[internal]
    fn get_mapping_slot_key(mapping_key: u256, slot_index: u256) -> u256 {
        let mut encoded_array = array![mapping_key, slot_index];
        keccak::keccak_u256s_be_inputs(encoded_array.span()).byte_reverse()
    }

    #[internal]
    fn get_storage_slot(
        self: @ContractState,
        timestamp: u32,
        l1_contract_address: EthAddress,
        slot_index: u256,
        mapping_key: u256,
        serialized_tree: Span<felt252>
    ) -> u256 {
        let mut serialized_tree = serialized_tree;
        let tree = Serde::<BinarySearchTree>::deserialize(ref serialized_tree).unwrap();

        // Map timestamp to closest L1 block number that occured before the timestamp.
        let l1_block_number = ITimestampRemappersDispatcher {
            contract_address: self._timestamp_remappers.read()
        }
            .get_closest_l1_block_number(tree, timestamp.into())
            .unwrap();

        // Computes the key of the EVM storage slot from the index of the mapping in storage and the mapping key.
        let slot_key = get_mapping_slot_key(slot_index, mapping_key);

        // Returns the value of the storage slot of account: `l1_contract_address` at key: `slot_key` and block number: `l1_block_number`.
        let slot_value = IEVMFactsRegistryDispatcher {
            contract_address: self._facts_registry.read()
        }
            .get_slot_value(l1_contract_address.into(), l1_block_number, slot_key);

        assert(slot_value.is_non_zero(), 'Slot is zero');

        slot_value
    }
}

#[cfg(test)]
mod tests {
    use super::SingleSlotProof;
    use debug::PrintTrait;

    #[test]
    #[available_gas(10000000)]
    fn get_mapping_slot_key() {
        let slot_index = 1_u256;
        let mapping_key = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045_u256;
        let slot_key = SingleSlotProof::get_mapping_slot_key(mapping_key, slot_index);
        slot_key.print();
    }
}

