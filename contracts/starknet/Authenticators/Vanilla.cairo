%lang starknet
from contracts.starknet.lib.execute import execute

//
// @title Vanilla Authenticator
// @author SnapshotLabs
// @notice Contract to allow bypassing of authentication for Snapshot X users
//

@external
func authenticate{syscall_ptr: felt*, range_check_ptr}(
    target: felt, function_selector: felt, calldata_len: felt, calldata: felt*
) -> () {
    execute(target, function_selector, calldata_len, calldata);
    return ();
}
