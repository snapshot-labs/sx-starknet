%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_equal

//
// @title Ethereum Transaction Authentication Library
// @author SnapshotLabs
// @notice A library to handle the authorization of actions within Snapshot X via transactions with an Ethereum account
//

// @dev Address of the StarkNet Commit Ethereum contract which acts as the origin address of the messages sent to the contract
@storage_var
func EthTx_starknet_commit_address_store() -> (res: felt) {
}

// @dev Stores the sender address for each hash committed to the contract
@storage_var
func EthTx_commit_store(hash: felt) -> (address: felt) {
}

namespace EthTx {
    // @dev Initializes the library, must be called in the constructor of contracts that use the library
    // @param starknet_commit_address The address of the StarkNet Commit contract on Ethereum
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        starknet_commit_address: felt
    ) {
        EthTx_starknet_commit_address_store.write(value=starknet_commit_address);
        return ();
    }

    // @dev Stores a hash that was committed on Ethereum, this should be called by the @l1_handler in the contract only
    // @param origin The address of the origin Ethereum contract for the L1->L2 message
    // @param sender The Ethereum address of the user that committed the hash to the StarkNet Commit contract
    func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
        origin: felt, sender: felt, hash: felt
    ) {
        // Check L1 message origin is equal to the StarkNet Commit address.
        let (starknet_commit_address) = EthTx_starknet_commit_address_store.read();
        with_attr error_message("EthTx: Invalid message origin address") {
            assert origin = starknet_commit_address;
        }
        // Note: If the same hash is committed twice by the same sender, then the mapping will be overwritten but with the same value as before.
        EthTx_commit_store.write(hash, sender);
        return ();
    }

    // @dev Checks to see if a commit exists and was made by a specified address, if so clears it from the contract. Otherwise throws
    // @param hash The commit hash to consume
    // @param address The sender address to check the commit against
    func consume_commit{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}(
        hash: felt, sender: felt
    ) {
        // Check that the hash has been received by the contract from the StarkNet Commit contract
        let (stored_address) = EthTx_commit_store.read(hash);
        with_attr error_message("EthTx: Hash not yet committed or already executed") {
            assert_not_equal(stored_address, 0);
        }
        // The sender of the commit on L1 must be the same as the address in the calldata.
        with_attr error_message("EthTx: Commit made by invalid L1 address") {
            assert sender = stored_address;
        }
        EthTx_commit_store.write(hash, 0);
        return ();
    }
}
