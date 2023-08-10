use array::ArrayTrait;
use traits::Into;
use integer::u256_from_felt252;
use starknet::{ContractAddress, EthAddress};

impl Felt252ArrayIntoU256Array of Into<Array<felt252>, Array<u256>> {
    fn into(self: Array<felt252>) -> Array<u256> {
        let mut arr = ArrayTrait::<u256>::new();
        let mut i = 0_usize;
        loop {
            if i >= self.len() {
                break ();
            }
            arr.append((*self.at(i)).into());
            i += 1;
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
