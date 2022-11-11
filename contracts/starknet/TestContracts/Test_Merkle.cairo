%lang starknet
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.starknet.lib.merkle import Merkle

@view
func testAssertValidLeaf{range_check_ptr, pedersen_ptr: HashBuiltin*}(
    root: felt, leaf_len: felt, leaf: felt*, proof_len: felt, proof: felt*
) {
    alloc_locals;
    Merkle.assert_valid_leaf(root, leaf_len, leaf, proof_len, proof);
    return ();
}
