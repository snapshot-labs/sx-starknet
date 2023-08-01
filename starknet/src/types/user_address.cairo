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
    EthereumAddress: EthAddress,
    // Custom address type to provide compatibility with any address that can be represented as a u256.
    CustomAddress: u256
}

impl LegacyHashUserAddress of LegacyHash<UserAddress> {
    fn hash(state: felt252, value: UserAddress) -> felt252 {
        match value {
            UserAddress::StarknetAddress(address) => LegacyHash::<felt252>::hash(
                state, address.into()
            ),
            UserAddress::EthereumAddress(address) => LegacyHash::<felt252>::hash(
                state, address.into()
            ),
            UserAddress::CustomAddress(address) => LegacyHash::<u256>::hash(state, address),
        }
    }
}

trait UserAddressTrait {
    fn to_starknet_address(self: UserAddress) -> ContractAddress;
    fn to_ethereum_address(self: UserAddress) -> EthAddress;
    fn to_custom_address(self: UserAddress) -> u256;
}

impl UserAddressImpl of UserAddressTrait {
    fn to_starknet_address(self: UserAddress) -> ContractAddress {
        match self {
            UserAddress::StarknetAddress(address) => address,
            UserAddress::EthereumAddress(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::CustomAddress(_) => {
                panic_with_felt252('Incorrect address type')
            }
        }
    }

    fn to_ethereum_address(self: UserAddress) -> EthAddress {
        match self {
            UserAddress::StarknetAddress(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::EthereumAddress(address) => address,
            UserAddress::CustomAddress(_) => {
                panic_with_felt252('Incorrect address type')
            }
        }
    }

    fn to_custom_address(self: UserAddress) -> u256 {
        match self {
            UserAddress::StarknetAddress(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::EthereumAddress(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::CustomAddress(address) => address,
        }
    }
}
