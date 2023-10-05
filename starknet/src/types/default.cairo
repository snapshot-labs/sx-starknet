use starknet::{ContractAddress, contract_address_const};

// Required for the proposal derivation. Ideally, ContractAddress would impl Default in the corelib.
impl ContractAddressDefault of Default<ContractAddress> {
    fn default() -> ContractAddress {
        contract_address_const::<0>()
    }
}
