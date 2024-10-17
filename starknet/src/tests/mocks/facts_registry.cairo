#[starknet::contract]
mod MockFactsRegistry {
    use sx::external::herodotus::IEVMFactsRegistry;
    use sx::external::herodotus::{BinarySearchTree, MapperId, Words64};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FactsRegistry of IEVMFactsRegistry<ContractState> {
        fn get_storage(
            self: @ContractState,
            block: u256,
            account: felt252,
            slot: u256,
            mpt_proof: Span<Words64>
        ) -> u256 {
            return 1;
        }
    }
}
