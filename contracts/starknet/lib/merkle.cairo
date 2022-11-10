// SPDX-License-Identifier: MIT

%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_lt, assert_not_zero, assert_nn_le
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.hash import hash2

from contracts.starknet.lib.stark_eip191 import StarkEIP191
from contracts.starknet.lib.eip712 import EIP712
from contracts.starknet.lib.eth_tx import EthTx
from contracts.starknet.lib.array_utils import ArrayUtils

//
// @title Merkle Proof Library
// @author SnapshotLabs
// @notice A library to to verify merkle proofs
//

namespace Merkle {
    func assert_valid_leaf{pedersen_ptr: HashBuiltin*, range_check_ptr}(
        root: felt, leaf_len: felt, leaf: felt*, proof_len: felt, proof: felt*
    ) {
        let (leaf_node) = ArrayUtils.hash(leaf_len, leaf);
        let (computed_root) = compute_merkle_root(leaf_node, proof_len, proof);
        with_attr error_message("Merkle: Invalid proof") {
            assert root = computed_root;
        }
        return ();
    }

    func compute_merkle_root{pedersen_ptr: HashBuiltin*, range_check_ptr}(
        node: felt, proof_len: felt, proof: felt*
    ) -> (root: felt) {
        alloc_locals;

        if (proof_len == 0) {
            return (node,);
        }
        let (le) = is_le_felt(node, proof[0]);
        if (le == 1) {
            let (n) = hash2{hash_ptr=pedersen_ptr}(node, proof[0]);
            node = n;
        } else {
            let (n) = hash2{hash_ptr=pedersen_ptr}(proof[0], node);
            node = n;
        }

        let (root) = compute_merkle_root(node, proof_len - 1, &proof);
        return (root,);
    }
}
