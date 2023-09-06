#[starknet::contract]
mod EthBalanceOfVotingStrategy {
    use starknet::{EthAddress, ContractAddress};
    use integer::u256_from_felt252;
    use sx::{
        interfaces::IVotingStrategy, types::{UserAddress, UserAddressTrait},
        utils::single_slot_proof::SingleSlotProof
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl EthBalanceOfVotingStrategy of IVotingStrategy<ContractState> {
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            params: Span<felt252>,
            user_params: Span<felt252>,
        ) -> u256 {
            // Cast voter address to an Ethereum address
            // Will revert if the address is not a valid Ethereum address
            let voter = voter.to_ethereum_address();

            // Decode params 
            let mut params = params;
            let (l1_account_address, slot_index) = Serde::<(
                EthAddress, u256
            )>::deserialize(ref params)
                .unwrap();

            // Get the balance of the voter at the given block timestamp
            // TODO: temporary until components are released
            let state = SingleSlotProof::unsafe_new_contract_state();
            let balance = SingleSlotProof::get_storage_slot(
                @state, timestamp, l1_account_address, slot_index, voter.into(), user_params
            );
            balance
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        timestamp_remappers: ContractAddress,
        facts_registry: ContractAddress
    ) {
        // TODO: temporary until components are released
        let mut state = SingleSlotProof::unsafe_new_contract_state();
        SingleSlotProof::initializer(ref state, timestamp_remappers, facts_registry);
    }

    // TODO: temp till PR with this is merged
    impl TIntoU256<T, impl TIntoFelt252: Into<T, felt252>> of Into<T, u256> {
        fn into(self: T) -> u256 {
            u256_from_felt252(self.into())
        }
    }
}
