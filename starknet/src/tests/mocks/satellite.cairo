#[starknet::contract]
mod MockSatellite {
    use sx::external::herodotus::ISatellite;
    use starknet::EthAddress;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Satellite of ISatellite<ContractState> {
        fn storageSlot(
            self: @ContractState,
            chain_id: u256,
            block_number: u256,
            account: EthAddress,
            slot_index: u256,
        ) -> u256 {
            return 1;
        }

        fn timestamp(self: @ContractState, chain_id: u256, timestamp: u256) -> u256 {
            return 1;
        }
    }
}

