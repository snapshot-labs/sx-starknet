#[starknet::contract]
mod MockSatellite {
    use sx::external::herodotus::{ISatellite, Words64, AccountField};
    use starknet::EthAddress;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Satellite of ISatellite<ContractState> {
        fn accountField(
            self: @ContractState,
            chain_id: u256,
            block_number: u256,
            account: EthAddress,
            field: AccountField,
        ) -> u256 {
            return 1;
        }

        fn verifyOnlyStorage(
            self: @ContractState,
            slot: u256,
            storage_root: u256,
            storage_slot_mpt_proof: Span<Words64>,
        ) -> u256 {
            return 1;
        }

        fn timestamp(self: @ContractState, chain_id: u256, timestamp: u256) -> u256 {
            return 1;
        }
    }
}

