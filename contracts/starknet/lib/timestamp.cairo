%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IL1HeadersStore {
    func get_latest_l1_block() -> (number: felt) {
    }
}

@storage_var
func Timestamp_l1_headers_store() -> (res: felt) {
}

@storage_var
func Timestamp_timestamp_to_eth_block_number(timestamp: felt) -> (number: felt) {
}

namespace Timestamp {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        l1_headers_store_address: felt
    ) {
        Timestamp_l1_headers_store.write(value=l1_headers_store_address);
        return ();
    }

    func get_eth_block_number{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        timestamp: felt
    ) -> (number: felt) {
        let (number) = Timestamp_timestamp_to_eth_block_number.read(timestamp);
        if (number != 0) {
            // The timestamp has already be queried in fossil and stored. Therefore we can just return the stored value
            // This branch will be taken whenever a vote is cast as the mapping value would be set at proposal creation.
            return (number,);
        } else {
            // The timestamp has not yet been queried in fossil. Therefore we must query Fossil for the latest eth block
            // number stored there and store it here in the mapping indexed by the timestamp provided.
            // This branch will be taken whenever a proposal is created, except for the (rare) case of multiple proposals
            // being created in the same block.
            let (l1_headers_store_address) = Timestamp_l1_headers_store.read();
            let (number) = IL1HeadersStore.get_latest_l1_block(l1_headers_store_address);
            Timestamp_timestamp_to_eth_block_number.write(timestamp, number);
            return (number,);
        }
    }
}
