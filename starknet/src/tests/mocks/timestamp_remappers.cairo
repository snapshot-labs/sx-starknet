#[starknet::contract]
mod MockTimestampRemappers {
    use sx::external::herodotus::ITimestampRemappers;
    use sx::external::herodotus::{BinarySearchTree, MapperId};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl TimestampRemappers of ITimestampRemappers<ContractState> {
        fn get_closest_l1_block_number(
            self: @ContractState, tree: BinarySearchTree, timestamp: u256
        ) -> Result<Option<u256>, felt252> {
            return Result::Ok(Option::Some(1));
        }

        // Getter for the last timestamp of a given mapper.
        fn get_last_mapper_timestamp(self: @ContractState, mapper_id: MapperId) -> u256 {
            return 1;
        }
    }
}
