// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_eq
from starkware.cairo.common.math import assert_nn_le

from contracts.starknet.lib.timestamp import Timestamp
from contracts.starknet.lib.slot_key import SlotKey
from contracts.starknet.lib.math_utils import MathUtils

//
// @title Ethereum single slot proof library
// @author SnapshotLabs
// @notice A library to prove values from the Ethereum state on StarkNet using the Fossil storage verifier
//

struct StorageSlot {
    word_1: felt,
    word_2: felt,
    word_3: felt,
    word_4: felt,
}

@contract_interface
namespace IFactsRegistry {
    func get_storage_uint(
        block: felt,
        account_160: felt,
        slot: StorageSlot,
        proof_sizes_bytes_len: felt,
        proof_sizes_bytes: felt*,
        proof_sizes_words_len: felt,
        proof_sizes_words: felt*,
        proofs_concat_len: felt,
        proofs_concat: felt*,
    ) -> (res: Uint256) {
    }
}

// @dev Stores the address of the Fossil fact registry contract
@storage_var
func SingleSlotProof_fact_registry_store() -> (res: felt) {
}

namespace SingleSlotProof {
    // @dev Initializes the library, must be called in the constructor of contracts that use the library
    // @param fact_registry_address Address of the Fossil fact registry contract
    // @param l1_headers_store_address Address of the Fossil L1 headers store contract
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        fact_registry_address: felt, l1_headers_store_address: felt
    ) {
        SingleSlotProof_fact_registry_store.write(value=fact_registry_address);
        Timestamp.initializer(l1_headers_store_address);
        return ();
    }

    // @dev Returns the value of a mapping and block number of the Ethereum state if a valid proof is supplied
    // @param timestamp The snapshot timestamp, which will get mapped to a block number
    // @param mapping_key The key of the mapping that one wants the value from (eg. _address for balances[_address])
    // @param params Array of parameters required to verify the storage proof
    // @param proofs Array containing encoded storage proof data
    // @return storage_slot The slot value
    func get_storage_slot{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        timestamp: felt,
        mapping_key: felt,
        params_len: felt,
        params: felt*,
        proofs_len: felt,
        proofs: felt*,
    ) -> (storage_slot: Uint256) {
        alloc_locals;
        let (fact_registry_addr) = SingleSlotProof_fact_registry_store.read();

        // Mapping timestamp to an ethereum block number
        let (eth_block_number) = Timestamp.get_eth_block_number(timestamp);
        let eth_block_number = eth_block_number - 1;  // temp shift - waiting for Fossil fix

        // Decoding encoded proof data
        let (
            slot,
            proof_sizes_bytes_len,
            proof_sizes_bytes,
            proof_sizes_words_len,
            proof_sizes_words,
            proofs_concat_len,
            proofs_concat,
        ) = _decode_param_array(proofs_len, proofs);

        // Extracting individual parameters from parameter array
        with_attr error_message("SingleSlotProof: Invalid size parameters array") {
            assert params_len = 2;
        }
        // Contract address where the desired slot resides
        let contract_address = params[0];
        // Index of the desired slot
        let slot_index = params[1];

        let (valid_slot) = SlotKey.get_mapping_slot_key(slot_index, mapping_key);
        let (slot_uint256) = MathUtils.words_to_uint256(
            slot.word_1, slot.word_2, slot.word_3, slot.word_4
        );
        with_attr error_message("SingleSlotProof: Invalid slot proof provided") {
            // Checking that the slot proof corresponds to the correct slot
            assert valid_slot = slot_uint256;
            // Calling Fossil Fact Registry to verify the storage proof of the slot value
            let (storage_slot) = IFactsRegistry.get_storage_uint(
                fact_registry_addr,
                eth_block_number,
                contract_address,
                slot,
                proof_sizes_bytes_len,
                proof_sizes_bytes,
                proof_sizes_words_len,
                proof_sizes_words,
                proofs_concat_len,
                proofs_concat,
            );
        }

        let (is_zero) = uint256_eq(Uint256(0, 0), storage_slot);
        with_attr error_message("SingleSlotProof: Slot is zero") {
            is_zero = 0;
        }

        return (storage_slot,);
    }
}

func _decode_param_array{range_check_ptr}(param_array_len: felt, param_array: felt*) -> (
    slot: StorageSlot,
    proof_sizes_bytes_len: felt,
    proof_sizes_bytes: felt*,
    proof_sizes_words_len: felt,
    proof_sizes_words: felt*,
    proofs_concat_len: felt,
    proofs_concat: felt*,
) {
    assert_nn_le(5, param_array_len);
    let slot: StorageSlot = StorageSlot(
        param_array[0], param_array[1], param_array[2], param_array[3]
    );
    let num_nodes = param_array[4];
    let proof_sizes_bytes_len = num_nodes;
    let proof_sizes_bytes = param_array + 5;
    let proof_sizes_words_len = num_nodes;
    let proof_sizes_words = param_array + 5 + num_nodes;
    let proofs_concat = param_array + 5 + 2 * num_nodes;
    let proofs_concat_len = param_array_len - 5 - 2 * num_nodes;

    return (
        slot,
        proof_sizes_bytes_len,
        proof_sizes_bytes,
        proof_sizes_words_len,
        proof_sizes_words,
        proofs_concat_len,
        proofs_concat,
    );
}
