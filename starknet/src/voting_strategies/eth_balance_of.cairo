#[starknet::contract]
mod EthBalanceOfVotingStrategy {
    use traits::Into;
    use starknet::ContractAddress;
    use sx::interfaces::IVotingStrategy;
    use sx::utils::single_slot_proof::SingleSlotProof;

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl EthBalanceOfVotingStrategy of IVotingStrategy<ContractState> {
        fn get_voting_power(
            self: @ContractState,
            timestamp: u64,
            voter: ContractAddress,
            params: Array<felt252>,
            user_params: Array<felt252>,
        ) -> u256 {
            // Resolve timestamp to block number
            //TODO: dummy var for now. Remove when timestamps are replaced with block numbers
            let block_number = 1;

            // Decode params 
            let contract_address = (*params[0]).into();
            let slot_index = (*params[1]).into();

            // TODO: temporary until components are released
            let state: SingleSlotProof::ContractState =
                SingleSlotProof::unsafe_new_contract_state();

            // Get the balance of the voter at the given block number
            let balance = SingleSlotProof::get_storage_slot(
                @state, block_number, voter.into(), contract_address, slot_index, user_params
            );
            balance
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, facts_registry: ContractAddress, l1_headers_store: ContractAddress
    ) {
        // TODO: temporary until components are released
        let mut state: SingleSlotProof::ContractState =
            SingleSlotProof::unsafe_new_contract_state();
        SingleSlotProof::initializer(ref state, facts_registry);
    }
}
