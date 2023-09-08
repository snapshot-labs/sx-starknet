use starknet::{ContractAddress, contract_address_const};
use sx::types::Strategy;

/// A struct representing the calldata of the update_settings function.
/// This allows smooth UX as updating multiple values can be done in a single call.
/// If a value is not to be updated, it should be set to the corresponding NO_UPDATE value (see `NoUpdateTrait`).
#[derive(Clone, Drop, Serde)]
struct UpdateSettingsCalldata {
    min_voting_duration: u32,
    max_voting_duration: u32,
    voting_delay: u32,
    metadata_uri: Array<felt252>,
    dao_uri: Array<felt252>,
    proposal_validation_strategy: Strategy,
    proposal_validation_strategy_metadata_uri: Array<felt252>,
    authenticators_to_add: Array<ContractAddress>,
    authenticators_to_remove: Array<ContractAddress>,
    voting_strategies_to_add: Array<Strategy>,
    voting_strategies_metadata_uris_to_add: Array<Array<felt252>>,
    voting_strategies_to_remove: Array<u8>,
}

// TODO: use `Default` trait
trait UpdateSettingsCalldataTrait {
    fn default() -> UpdateSettingsCalldata;
}

// Theoretically could derive a value with a proc_macro,
// since NO_UPDATE values are simply the first x bytes of a hash.
trait NoUpdateTrait<T> {
    fn no_update() -> T;
    fn should_update(self: @T) -> bool;
}

// Obtained by keccak256 hashing the string "No update", and then taking the corresponding number of bytes.
// Evaluates to: 0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048ba

impl NoUpdateU32 of NoUpdateTrait<u32> {
    fn no_update() -> u32 {
        0xf2cda9b1
    }

    fn should_update(self: @u32) -> bool {
        *self != 0xf2cda9b1
    }
}

impl NoUpdateFelt252 of NoUpdateTrait<felt252> {
    fn no_update() -> felt252 {
        // First 248 bits
        0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048
    }

    fn should_update(self: @felt252) -> bool {
        *self != 0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048
    }
}

impl NoUpdateContractAddress of NoUpdateTrait<ContractAddress> {
    fn no_update() -> ContractAddress {
        // First 248 bits
        contract_address_const::<0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048>()
    }

    fn should_update(self: @ContractAddress) -> bool {
        *self != contract_address_const::<0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048>()
    }
}

impl NoUpdateStrategy of NoUpdateTrait<Strategy> {
    fn no_update() -> Strategy {
        Strategy {
            address: contract_address_const::<0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048>(),
            params: array![],
        }
    }

    fn should_update(self: @Strategy) -> bool {
        *self
            .address != contract_address_const::<0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048>()
    }
}

impl NoUpdateString of NoUpdateTrait<Array<felt252>> {
    fn no_update() -> Array<felt252> {
        array!['No update']
    }

    fn should_update(self: @Array<felt252>) -> bool {
        match self.get(0) {
            Option::Some(e) => {
                *e.unbox() != 'No update'
            },
            Option::None => true,
        }
    }
}

/// Strings should use `NoUpdateString` (since String currently is not an official type).
impl NoUpdateArray<T> of NoUpdateTrait<Array<T>> {
    fn no_update() -> Array<T> {
        array![]
    }

    fn should_update(self: @Array<T>) -> bool {
        self.len() != 0
    }
}

impl UpdateSettingsCalldataImpl of UpdateSettingsCalldataTrait {
    /// Generates an `UpdateSettingsCalldata` struct with all values set to `NO_UPDATE`.
    fn default() -> UpdateSettingsCalldata {
        UpdateSettingsCalldata {
            min_voting_duration: NoUpdateU32::no_update(),
            max_voting_duration: NoUpdateU32::no_update(),
            voting_delay: NoUpdateU32::no_update(),
            metadata_uri: NoUpdateString::no_update(),
            dao_uri: NoUpdateString::no_update(),
            proposal_validation_strategy: NoUpdateStrategy::no_update(),
            proposal_validation_strategy_metadata_uri: NoUpdateString::no_update(),
            authenticators_to_add: NoUpdateArray::no_update(),
            authenticators_to_remove: NoUpdateArray::no_update(),
            voting_strategies_to_add: NoUpdateArray::no_update(),
            voting_strategies_metadata_uris_to_add: NoUpdateArray::no_update(),
            voting_strategies_to_remove: NoUpdateArray::no_update(),
        }
    }
}
