use starknet::{ContractAddress, contract_address::ContractAddressZeroable};

// Ideally, ContractAddress would impl Default in the corelib.
impl ContractAddressDefault of Default<ContractAddress> {
    fn default() -> ContractAddress {
        ContractAddressZeroable::zero()
    }
}
