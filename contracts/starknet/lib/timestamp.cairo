%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IL1HeadersStore:
    func get_latest_l1_block() -> (number : felt):
    end
end

@storage_var
func l1_headers_store() -> (res : felt):
end

@storage_var
func timestamp_to_eth_block_number(timestamp : felt) -> (number : felt):
end

func get_eth_block_number{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    timestamp : felt
) -> (number : felt):
    let (number) = timestamp_to_eth_block_number.read(timestamp)
    if number != 0:
        # The timestamp has already be queried in fossil and stored. Therefore we can just return the stored value
        # This branch will be taken whenever anyone casts a vote.
        return (number)
    else:
        # The timestamp has not yet been queried in fossil. Therefore we must query Fossil for the latest eth block
        # number stored there and store it here in the mapping indexed by the timestamp provided.
        let (l1_headers_store_address) = l1_headers_store.read()
        let (number) = IL1HeadersStore.get_latest_l1_block(l1_headers_store_address)
        timestamp_to_eth_block_number.write(timestamp, number)
        return (number)
    end
end
