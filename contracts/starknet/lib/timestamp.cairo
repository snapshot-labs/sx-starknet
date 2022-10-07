%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

//
// @title Timestamp Resolver
// @author SnapshotLabs
// @notice Snapshot X uses timestamps for a proposal snapshot, however certain voting strategies require Ethereum block numbers
// @notice This library provides the functionality to resolve timestamps to Ethereum block numbers with a one-to-one mapping
//

@contract_interface
namespace IL1HeadersStore {
    func get_latest_l1_block() -> (number: felt) {
    }
}

// @dev Stores the address of the Fossil L1 Headers Store contract
@storage_var
func Timestamp_l1_headers_store() -> (res: felt) {
}

// @dev Stores the timestamp to Ethereum block number mapping
@storage_var
func Timestamp_timestamp_to_eth_block_number_store(timestamp: felt) -> (eth_block_number: felt) {
}

namespace Timestamp {
    // @dev Initializes the library, must be called in the constructor of contracts that use the library
    // @param l1_headers_store_address Address of the Fossil L1 headers store contract
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        l1_headers_store_address: felt
    ) {
        Timestamp_l1_headers_store.write(value=l1_headers_store_address);
        return ();
    }

    // @dev Resolves a provided timestamp to an Ethereum block number with a one-to-one mapping
    // @dev timestamp The timestamp that should be resolved
    // @return eth_block_number The Ethereum block number
    func get_eth_block_number{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        timestamp: felt
    ) -> (eth_block_number: felt) {
        let (eth_block_number) = Timestamp_timestamp_to_eth_block_number_store.read(timestamp);
        if (eth_block_number != 0) {
            // The timestamp has already be queried in fossil and stored. Therefore we can just return the stored value
            // This branch will be taken whenever a vote is cast as the mapping value would be set at proposal creation.
            return (eth_block_number,);
        } else {
            // The timestamp has not yet been queried in fossil. Therefore we must query Fossil for the latest eth block
            // number stored there and store it here in the mapping indexed by the timestamp provided.
            // This branch will be taken whenever a proposal is created, except for the (rare) case of multiple proposals
            // being created in the same block.
            let (l1_headers_store_address) = Timestamp_l1_headers_store.read();
            let (eth_block_number) = IL1HeadersStore.get_latest_l1_block(l1_headers_store_address);
            Timestamp_timestamp_to_eth_block_number_store.write(timestamp, eth_block_number);
            return (eth_block_number,);
        }
    }
}
