use array::{ArrayTrait, SpanTrait};
use traits::Into;
use option::OptionTrait;
use core::keccak;
use core::integer::U8IntoU256;
use sx::types::{Strategy, IndexedStrategy};
use sx::utils::constants::{
    STRATEGY_TYPEHASH_LOW, STRATEGY_TYPEHASH_HIGH, INDEXED_STRATEGY_TYPEHASH_LOW,
    INDEXED_STRATEGY_TYPEHASH_HIGH,
};
use sx::utils::endian::ByteReverse;
use sx::utils::into::{TIntoU256, Felt252SpanIntoU256Array};

trait KeccakStructHash<T> {
    fn keccak_struct_hash(self: @T) -> u256;
}

impl KeccakStructHashStrategy of KeccakStructHash<Strategy> {
    fn keccak_struct_hash(self: @Strategy) -> u256 {
        let mut encoded_data = ArrayTrait::<u256>::new();
        encoded_data.append(u256 { low: STRATEGY_TYPEHASH_LOW, high: STRATEGY_TYPEHASH_HIGH });
        encoded_data.append((*self.address).into());
        encoded_data.append(self.params.span().keccak_struct_hash());
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}

impl KeccakStructHashArray of KeccakStructHash<Span<felt252>> {
    fn keccak_struct_hash(self: @Span<felt252>) -> u256 {
        let mut encoded_data: Array<u256> = (*self).into();
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}

impl KeccakStructHashIndexedStrategy of KeccakStructHash<IndexedStrategy> {
    fn keccak_struct_hash(self: @IndexedStrategy) -> u256 {
        let mut encoded_data = ArrayTrait::<u256>::new();
        encoded_data
            .append(
                u256 { low: INDEXED_STRATEGY_TYPEHASH_LOW, high: INDEXED_STRATEGY_TYPEHASH_HIGH }
            );
        // let index_felt: felt252 = (*self.index).into();
        encoded_data.append(U8IntoU256::into(*self.index));

        encoded_data.append(self.params.span().keccak_struct_hash());
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}

impl KeccakStructHashIndexedStrategyArray of KeccakStructHash<Span<IndexedStrategy>> {
    fn keccak_struct_hash(self: @Span<IndexedStrategy>) -> u256 {
        let mut self_ = *self;
        let mut encoded_data = ArrayTrait::<u256>::new();
        loop {
            match self_.pop_front() {
                Option::Some(item) => {
                    encoded_data.append(item.keccak_struct_hash());
                },
                Option::None(_) => {
                    break keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse();
                }
            };
        }
    }
}
