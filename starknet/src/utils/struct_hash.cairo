use hash::LegacyHash;
use sx::{
    types::{Strategy, IndexedStrategy},
    utils::{
        constants::{
            STARKNET_MESSAGE, DOMAIN_TYPEHASH, STRATEGY_TYPEHASH, INDEXED_STRATEGY_TYPEHASH,
            U256_TYPEHASH, PROPOSE_TYPEHASH, VOTE_TYPEHASH, UPDATE_PROPOSAL_TYPEHASH
        },
        legacy_hash::LegacyHashSpanFelt252,
    }
};

/// Struct hash trait helper.
trait StructHash<T> {k
    fn struct_hash(self: @T) -> felt252;
}

impl StructHashSpanFelt252 of StructHash<Span<felt252>> {
    fn struct_hash(self: @Span<felt252>) -> felt252 {
        let mut call_data_state = LegacyHash::hash(0, *self);
        call_data_state = LegacyHash::hash(call_data_state, (*self).len());
        call_data_state
    }
}

impl StructHashStrategy of StructHash<Strategy> {
    fn struct_hash(self: @Strategy) -> felt252 {
        let mut encoded_data = array![];
        STRATEGY_TYPEHASH.serialize(ref encoded_data);
        (*self.address).serialize(ref encoded_data);
        self.params.span().struct_hash().serialize(ref encoded_data);
        encoded_data.span().struct_hash()
    }
}

impl StructHashIndexedStrategy of StructHash<IndexedStrategy> {
    fn struct_hash(self: @IndexedStrategy) -> felt252 {
        let mut encoded_data = array![];
        INDEXED_STRATEGY_TYPEHASH.serialize(ref encoded_data);
        (*self.index).serialize(ref encoded_data);
        self.params.span().struct_hash().serialize(ref encoded_data);
        encoded_data.span().struct_hash()
    }
}

impl StructHashIndexedStrategySpan of StructHash<Span<IndexedStrategy>> {
    fn struct_hash(self: @Span<IndexedStrategy>) -> felt252 {
        let mut self_ = *self;
        let mut encoded_data = array![];
        loop {
            match self_.pop_front() {
                Option::Some(item) => {
                    encoded_data.append(item.struct_hash());
                },
                Option::None(_) => {
                    break encoded_data.span().struct_hash();
                },
            };
        }
    }
}

impl StructHashU256 of StructHash<u256> {
    fn struct_hash(self: @u256) -> felt252 {
        let mut encoded_data = array![];
        U256_TYPEHASH.serialize(ref encoded_data);
        self.serialize(ref encoded_data);
        encoded_data.span().struct_hash()
    }
}
