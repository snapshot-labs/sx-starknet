use array::{ArrayTrait};
use traits::Into;
use option::OptionTrait;
use clone::Clone;
use core::keccak;
use sx::types::{Strategy, IndexedStrategy};
use sx::utils::constants::{
    STRATEGY_TYPEHASH_LOW, STRATEGY_TYPEHASH_HIGH, INDEXED_STRATEGY_TYPEHASH_LOW,
    INDEXED_STRATEGY_TYPEHASH_HIGH,
};
use sx::utils::endian::{into_le_u64_array, ByteReverse};
use sx::utils::into::{ContractAddressIntoU256, EthAddressIntoU256, Felt252ArrayIntoU256Array};

trait Keccak<T> {
    fn keccak(self: T) -> u256;
}

impl KeccakStrategy of Keccak<Strategy> {
    fn keccak(self: Strategy) -> u256 {
        let mut encoded_data = ArrayTrait::<u256>::new();
        encoded_data.append(u256 { low: STRATEGY_TYPEHASH_LOW, high: STRATEGY_TYPEHASH_HIGH });
        encoded_data.append(self.address.into());
        encoded_data.append(self.params.keccak());
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}

impl KeccakArray of Keccak<Array<felt252>> {
    fn keccak(self: Array<felt252>) -> u256 {
        let mut encoded_data: Array<u256> = self.into();
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}

impl KeccakIndexedStrategy of Keccak<IndexedStrategy> {
    fn keccak(self: IndexedStrategy) -> u256 {
        let mut encoded_data = ArrayTrait::<u256>::new();
        encoded_data
            .append(
                u256 { low: INDEXED_STRATEGY_TYPEHASH_LOW, high: INDEXED_STRATEGY_TYPEHASH_HIGH }
            );
        let index_felt: felt252 = self.index.into();
        encoded_data.append(index_felt.into());
        encoded_data.append(self.params.keccak());
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}

impl KeccakIndexedStrategyArray of Keccak<Array<IndexedStrategy>> {
    fn keccak(self: Array<IndexedStrategy>) -> u256 {
        let mut encoded_data = ArrayTrait::<u256>::new();
        let mut i: usize = 0;
        loop {
            if i >= self.len() {
                break ();
            }
            encoded_data.append(self.at(i).clone().keccak());
        };
        keccak::keccak_u256s_be_inputs(encoded_data.span()).byte_reverse()
    }
}
