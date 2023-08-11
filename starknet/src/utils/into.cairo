use array::{ArrayTrait, SpanTrait};
use option::OptionTrait;
use traits::Into;
use integer::u256_from_felt252;
use starknet::{ContractAddress, EthAddress};

impl Felt252SpanIntoU256Array of Into<Span<felt252>, Array<u256>> {
    fn into(self: Span<felt252>) -> Array<u256> {
        let mut self = self;
        let mut arr = ArrayTrait::<u256>::new();
        loop {
            match self.pop_front() {
                Option::Some(num) => {
                    arr.append((*num).into());
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
        arr
    }
}

impl ContractAddressIntoU256 of Into<ContractAddress, u256> {
    fn into(self: ContractAddress) -> u256 {
        u256_from_felt252(self.into())
    }
}

impl EthAddressIntoU256 of Into<EthAddress, u256> {
    fn into(self: EthAddress) -> u256 {
        u256_from_felt252(self.into())
    }
}
