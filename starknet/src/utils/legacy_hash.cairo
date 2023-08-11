use hash::LegacyHash;
use traits::Into;
use starknet::EthAddress;
use sx::types::{Choice, UserAddress};
use array::{ArrayTrait, SpanTrait};

impl LegacyHashChoice of LegacyHash<Choice> {
    fn hash(state: felt252, value: Choice) -> felt252 {
        let choice: u8 = value.into();
        LegacyHash::hash(state, choice)
    }
}

impl LegacyHashEthAddress of LegacyHash<EthAddress> {
    fn hash(state: felt252, value: EthAddress) -> felt252 {
        LegacyHash::<felt252>::hash(state, value.into())
    }
}

impl LegacyHashSpan of LegacyHash<Span<felt252>> {
    fn hash(mut state: felt252, mut value: Span<felt252>) -> felt252 {
        let len = value.len();
        loop {
            match value.pop_front() {
                Option::Some(current) => {
                    state = LegacyHash::hash(state, *current);
                },
                Option::None => {
                    break;
                },
            };
        };
        LegacyHash::hash(
            state, len
        ) // append the length to conform to computeHashOnElements in starknet.js
    }
}

impl LegacyHashUserAddress of LegacyHash<UserAddress> {
    fn hash(state: felt252, value: UserAddress) -> felt252 {
        match value {
            UserAddress::Starknet(address) => LegacyHash::<felt252>::hash(state, address.into()),
            UserAddress::Ethereum(address) => LegacyHash::<felt252>::hash(state, address.into()),
            UserAddress::Custom(address) => LegacyHash::<u256>::hash(state, address),
        }
    }
}
