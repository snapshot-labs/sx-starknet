use core::zeroable::Zeroable;
use array::ArrayTrait;

// Each word is 64 bits
#[derive(Serde, Option, Drop)]
struct StorageSlot {
    word1: felt252,
    word2: felt252,
    word3: felt252,
    word4: felt252
}

#[derive(Serde, Option, Drop)]
struct Proofs {
    slot: StorageSlot,
    proof_size_bytes: Array<felt252>,
    proof_size_words: Array<felt252>,
    proofs_concat: Array<felt252>
}

#[starknet::interface]
trait IFactsRegistry<ContractState> {
    fn get_storage_uint(
        self: @ContractState,
        block: felt252,
        account_160: felt252,
        slot: StorageSlot,
        proof_sizes_bytes: Array<felt252>,
        proof_sizes_words: Array<felt252>,
        proofs_concat: Array<felt252>
    ) -> u256;
}

#[starknet::contract]
mod SingleSlotProof {
    use starknet::ContractAddress;
    use zeroable::Zeroable;
    use array::ArrayTrait;
    use serde::Serde;
    use option::OptionTrait;
    use traits::{Into, TryInto};
    use super::{
        StorageSlot, Proofs, IFactsRegistry, IFactsRegistryDispatcher, IFactsRegistryDispatcherTrait
    };
    use sx::utils::math;

    #[storage]
    struct Storage {
        _facts_registry: ContractAddress
    }

    #[internal]
    fn initializer(ref self: ContractState, facts_registry: ContractAddress) {
        self._facts_registry.write(facts_registry);
    }

    #[internal]
    fn get_mapping_slot_key(slot_index: u256, mapping_key: u256) -> u256 {
        let mut encoded_array = array![mapping_key, slot_index];
        keccak::keccak_u256s_le_inputs(encoded_array.span())
    }

    #[internal]
    fn get_storage_slot(
        self: @ContractState,
        timestamp: u32,
        contract_address: felt252,
        slot_index: u256,
        mapping_key: u256,
        encoded_proofs: Array<felt252>
    ) -> u256 {
        let slot_key = get_mapping_slot_key(slot_index, mapping_key);
        let mut s = encoded_proofs.span();
        let proofs: Proofs = Serde::<Proofs>::deserialize(ref s).unwrap();

        // Check proof corresponds to correct storage slot.
        assert(
            slot_key == math::u64s_into_u256(
                proofs.slot.word1.try_into().unwrap(),
                proofs.slot.word2.try_into().unwrap(),
                proofs.slot.word3.try_into().unwrap(),
                proofs.slot.word4.try_into().unwrap()
            ),
            'Invalid Proof'
        );

        let slot_value = IFactsRegistryDispatcher {
            contract_address: self._facts_registry.read()
        }
            .get_storage_uint(
                timestamp.into(),
                contract_address,
                proofs.slot,
                proofs.proof_size_bytes,
                proofs.proof_size_words,
                proofs.proofs_concat
            );

        assert(slot_value.is_non_zero(), 'Slot is zero');

        slot_value
    }
}

