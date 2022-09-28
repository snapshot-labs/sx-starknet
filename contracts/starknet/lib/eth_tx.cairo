%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_equal

// Address of the StarkNet Commit L1 contract which acts as the origin address of the messages sent to this contract.
@storage_var
func EthTx_starknet_commit_address_store() -> (res: felt) {
}

// Mapping between a commit and the L1 address of the sender.
@storage_var
func EthTx_commit_store(hash: felt) -> (address: felt) {
}

namespace EthTx {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        starknet_commit_address: felt
    ) {
        EthTx_starknet_commit_address_store.write(value=starknet_commit_address);
        return ();
    }

    func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        from_address: felt, sender: felt, hash: felt
    ) {
        // Check L1 message origin is equal to the StarkNet commit address.
        let (origin) = EthTx_starknet_commit_address_store.read();
        with_attr error_message("Invalid message origin address") {
            assert from_address = origin;
        }
        // Note: If the same hash is committed twice by the same sender, then the mapping will be overwritten but with the same value as before.
        EthTx_commit_store.write(hash, sender);
        return ();
    }

    // Checks to see if commit exists, if so clears it from the contract, else throws
    func consume_commit{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        hash: felt, address: felt
    ) {
        // Check that the hash has been received by the contract from the StarkNet Commit contract
        let (stored_address) = EthTx_commit_store.read(hash);
        with_attr error_message("Hash not yet committed or already executed") {
            assert_not_equal(stored_address, 0);
        }
        // The sender of the commit on L1 must be the same as the address in the calldata.
        with_attr error_message("Commit made by invalid L1 address") {
            assert address = stored_address;
        }
        // Clear the hash from the contract by writing the zero to the mapping.
        EthTx_commit_store.write(hash, 0);
        return ();
    }
}
