use hash::LegacyHash;
use traits::Into;
use array::SpanTrait;
use starknet::EthAddress;

impl LegacyHashEthAddress of LegacyHash<EthAddress> {
    fn hash(state: felt252, value: EthAddress) -> felt252 {
        LegacyHash::<felt252>::hash(state, value.into())
    }
}

impl LegacyHashSpanFelt252 of LegacyHash<Span<felt252>> {
    fn hash(state: felt252, mut value: Span<felt252>) -> felt252 {
        let mut call_data_state: felt252 = 0;
        loop {
            match value.pop_front() {
                Option::Some(item) => {
                    call_data_state = LegacyHash::hash(call_data_state, *item);
                },
                Option::None(_) => {
                    break call_data_state;
                },
            };
        }
    }
}
