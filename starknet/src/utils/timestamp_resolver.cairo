use core::traits::TryInto;
#[abi]
trait IL1HeadersStore {
    fn get_latest_l1_block() -> felt252;
}

#[contract]
mod TimestampResolver {
    use traits::TryInto;
    use option::OptionTrait;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use super::{IL1HeadersStoreDispatcher, IL1HeadersStoreDispatcherTrait};
    use sx::utils::math::U64Zeroable;

    struct Storage {
        _l1_headers_store: ContractAddress,
        _timestamp_to_eth_block_number: LegacyMap::<u64, u64>,
    }

    #[internal]
    fn initializer(l1_headers_store: ContractAddress) {
        _l1_headers_store::write(l1_headers_store);
    }

    #[internal]
    fn resolve_timestamp_to_eth_block_number(timestamp: u64) -> u64 {
        let eth_block_number = _timestamp_to_eth_block_number::read(timestamp);
        if eth_block_number.is_non_zero() {
            // The timestamp has already be queried in Herodotus and stored. Therefore we can just return the stored value
            // This branch will be taken whenever a vote is cast as the mapping value would be set at proposal creation.
            eth_block_number
        } else {
            // The timestamp has not yet been queried in fossil. Therefore we must query Fossil for the latest eth block
            // number stored there and store it here in the mapping indexed by the timestamp provided.
            // This branch will be taken whenever a proposal is created, except for the (rare) case of multiple proposals
            // being created in the same block.
            let l1_headers_store = _l1_headers_store::read();
            let eth_block_number = IL1HeadersStoreDispatcher {
                contract_address: _l1_headers_store::read()
            }.get_latest_l1_block().try_into().unwrap();
            _timestamp_to_eth_block_number::write(timestamp, eth_block_number);
            eth_block_number
        }
    }
}
