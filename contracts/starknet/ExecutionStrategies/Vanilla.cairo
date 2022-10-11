%lang starknet

from starkware.cairo.common.uint256 import Uint256

//
// @title Vanilla Execution Strategy
// @author SnapshotLabs
// @notice Dummy Execution Strategy
//

@external
func execute{syscall_ptr: felt*}(
    proposal_outcome: felt, execution_params_len: felt, execution_params: felt*
) {
    return ();
}
