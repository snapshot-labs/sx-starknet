%lang starknet
from contracts.starknet.lib.execute import execute

// Forwards `data` to `target` without verifying anything.
@external
func authenticate{syscall_ptr: felt*, range_check_ptr}(
    target: felt, function_selector: felt, calldata_len: felt, calldata: felt*
) -> () {
    // Call the contract
    execute(target, function_selector, calldata_len, calldata);

    return ();
}
