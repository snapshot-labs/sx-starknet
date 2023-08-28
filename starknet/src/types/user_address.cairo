use starknet::{ContractAddress, EthAddress};
use traits::{PartialEq, TryInto, Into};
use zeroable::Zeroable;
use serde::Serde;
use array::ArrayTrait;
use hash::{LegacyHash};
use debug::PrintTrait;

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
enum UserAddress {
    // Starknet address type
    Starknet: ContractAddress,
    // Ethereum address type
    Ethereum: EthAddress,
    // Custom address type to provide compatibility with any address that can be represented as a u256.
    Custom: u256
}

trait UserAddressTrait {
    fn to_starknet_address(self: UserAddress) -> ContractAddress;
    fn to_ethereum_address(self: UserAddress) -> EthAddress;
    fn to_custom_address(self: UserAddress) -> u256;
}

impl UserAddressImpl of UserAddressTrait {
    fn to_starknet_address(self: UserAddress) -> ContractAddress {
        match self {
            UserAddress::Starknet(address) => address,
            UserAddress::Ethereum(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::Custom(_) => {
                panic_with_felt252('Incorrect address type')
            }
        }
    }

    fn to_ethereum_address(self: UserAddress) -> EthAddress {
        match self {
            UserAddress::Starknet(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::Ethereum(address) => address,
            UserAddress::Custom(_) => {
                panic_with_felt252('Incorrect address type')
            }
        }
    }

    fn to_custom_address(self: UserAddress) -> u256 {
        match self {
            UserAddress::Starknet(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::Ethereum(_) => {
                panic_with_felt252('Incorrect address type')
            },
            UserAddress::Custom(address) => address,
        }
    }
}

impl UserAddressZeroable of Zeroable<UserAddress> {
    fn zero() -> UserAddress {
        panic_with_felt252('Undefined')
    }

    fn is_zero(self: UserAddress) -> bool {
        match self {
            UserAddress::Starknet(address) => address.is_zero(),
            UserAddress::Ethereum(address) => address.is_zero(),
            UserAddress::Custom(address) => address.is_zero(),
        }
    }

    fn is_non_zero(self: UserAddress) -> bool {
        !self.is_zero()
    }
}

#[cfg(test)]
mod tests {
    use zeroable::Zeroable;
    use super::{UserAddress, UserAddressZeroable};
    use starknet::{EthAddress, contract_address_const};

    #[test]
    fn test_is_zero() {
        assert(UserAddress::Starknet(contract_address_const::<0>()).is_zero(), 'is not zero');
        assert(UserAddress::Ethereum(EthAddress { address: 0 }).is_zero(), 'is not zero');
        assert(UserAddress::Custom(0_u256).is_zero(), 'is not zero');
    }

    #[test]
    fn test_is_zero_false_positive() {
        assert(
            UserAddress::Starknet(contract_address_const::<1>()).is_zero() == false,
            'false positive not zero'
        );
        assert(
            UserAddress::Ethereum(EthAddress { address: 1 }).is_zero() == false,
            'false positive not zero'
        );
        assert(UserAddress::Custom(1_u256).is_zero() == false, 'false positive not zero');
    }

    #[test]
    fn test_is_non_zero() {
        assert(UserAddress::Starknet(contract_address_const::<1>()).is_non_zero(), 'is zero');
        assert(UserAddress::Ethereum(EthAddress { address: 1 }).is_non_zero(), 'is zero');
        assert(UserAddress::Custom(1_u256).is_non_zero(), 'is zero');
    }

    #[test]
    fn test_is_non_zero_false_positive() {
        assert(
            UserAddress::Starknet(contract_address_const::<0>()).is_non_zero() == false,
            'false positive is zero'
        );
        assert(
            UserAddress::Ethereum(EthAddress { address: 0 }).is_non_zero() == false,
            'false positive is zero'
        );
        assert(UserAddress::Custom(0_u256).is_non_zero() == false, 'false positve not zero');
    }
}
