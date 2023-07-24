use starknet::{ContractAddress, EthAddress};
use traits::{PartialEq, TryInto, Into};
use hash::LegacyHash;
use serde::Serde;
use array::ArrayTrait;

#[derive(Copy, Drop, Serde, LegacyHash, PartialEq, starknet::Store)]
enum UserAddress {
    // Starknet address type
    StarknetAddress: ContractAddress,
    // Ethereum address type
    EthereumAddress: EthAddress
}

impl UserAddressIntoFelt of Into<UserAddress, felt252> {
    fn into(self: UserAddress) -> felt252 {
        match self {
            UserAddress::StarknetAddress(address) => address.into(),
            UserAddress::EthereumAddress(address) => address.into()
        }
    }
}

impl LegacyHashUserAddress of LegacyHash<UserAddress> {
    fn hash(state: felt252, value: UserAddress) -> felt252 {
        LegacyHash::<felt252>::hash(state, value.into())
    }
}

trait EnforceEnumTypeTrait {
    fn assert_starknet_address(self: UserAddress);
}

impl EnforceEnumTypeImpl of EnforceEnumTypeTrait {
    fn assert_starknet_address(self: UserAddress) {
        match self {
            UserAddress::StarknetAddress(_) => (),
            UserAddress::EthereumAddress(_) => {
                panic_with_felt252(2)
            }
        }
    }
}
