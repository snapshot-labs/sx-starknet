use starknet::ContractAddress;

// Ideally, ContractAddress would impl Default in the corelib.
impl ContractAddressDefault of Default<ContractAddress> {
    fn default() -> ContractAddress {
        Zeroable::zero()
    }
}
