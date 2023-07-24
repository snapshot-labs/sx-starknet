use hash::LegacyHash;
use traits::Into;
use starknet::EthAddress;

impl LegacyHashEthAddress of LegacyHash<EthAddress> {
    fn hash(state: felt252, value: EthAddress) -> felt252 {
        LegacyHash::<felt252>::hash(state, value.into())
    }
}
