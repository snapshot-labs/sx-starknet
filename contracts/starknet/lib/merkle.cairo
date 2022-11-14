// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.hash import hash2

from contracts.starknet.lib.array_utils import ArrayUtils

//
// @title Merkle Proof Library
// @author SnapshotLabs
// @notice A library to to verify merkle proofs
//

namespace Merkle {
    // @dev Asserts a given leaf is a member of the set with the specified root by verifing a proof
    // @param root The merkle root of the data
    // @param leaf The leaf data array
    // @param proof The proof
    func assert_valid_leaf{pedersen_ptr: HashBuiltin*, range_check_ptr}(
        root: felt, leaf_len: felt, leaf: felt*, proof_len: felt, proof: felt*
    ) {
        let (leaf_node) = ArrayUtils.hash(leaf_len, leaf);
        let (computed_root) = _compute_merkle_root(leaf_node, proof_len, proof);
        with_attr error_message("Merkle: Invalid proof") {
            assert root = computed_root;
        }
        return ();
    }
}

func _compute_merkle_root{pedersen_ptr: HashBuiltin*, range_check_ptr}(
    curr: felt, proof_len: felt, proof: felt*
) -> (root: felt) {
    alloc_locals;

    if (proof_len == 0) {
        return (curr,);
    }

    let le = is_le_felt(curr, proof[0]);
    if (le == 1) {
        let (n) = hash2{hash_ptr=pedersen_ptr}(curr, proof[0]);
        tempvar node = n;
    } else {
        let (n) = hash2{hash_ptr=pedersen_ptr}(proof[0], curr);
        tempvar node = n;
    }

    let (root) = compute_merkle_root(node, proof_len - 1, &proof[1]);
    return (root,);
}
