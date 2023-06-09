#[contract]
mod EthBalanceOfVotingStrategy {
    use traits::Into;
    use starknet::ContractAddress;
    use sx::interfaces::IVotingStrategy;
    use sx::utils::single_slot_proof::SingleSlotProof;
    use sx::utils::timestamp_resolver::TimestampResolver;

    impl EthBalanceOfVotingStrategy of IVotingStrategy {
        fn get_voting_power(
            timestamp: u64,
            voter: ContractAddress,
            params: Array<felt252>,
            user_params: Array<felt252>,
        ) -> u256 {
            // Resolve timestamp to block number
            let block_number = TimestampResolver::resolve_timestamp_to_eth_block_number(timestamp);

            // Decode params 
            let contract_address = (*params[0]).into();
            let slot_index = (*params[1]).into();

            // Get the balance of the voter at the given block number
            let balance = SingleSlotProof::get_storage_slot(
                block_number, voter.into(), contract_address, slot_index, user_params
            );
            balance
        }
    }

    #[constructor]
    fn constructor(facts_registry: ContractAddress, l1_headers_store: ContractAddress) {
        SingleSlotProof::initializer(facts_registry);
        TimestampResolver::initializer(l1_headers_store);
    }


    #[external]
    fn get_voting_power(
        timestamp: u64, voter: ContractAddress, params: Array<felt252>, user_params: Array<felt252>, 
    ) -> u256 {
        EthBalanceOfVotingStrategy::get_voting_power(timestamp, voter, params, user_params)
    }
}
