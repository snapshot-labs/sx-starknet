#[starknet::component]
mod SingleSlotProofComponent {
    use starknet::{ContractAddress, EthAddress, contract_address_to_felt252};
    use sx::external::herodotus::{ISatelliteDispatcher, ISatelliteDispatcherTrait};
    use sx::interfaces::i_single_slot_proof::ISingleSlotProof;

    #[storage]
    struct Storage {
        Singleslotproof_satellite_contract: ContractAddress,
        Singleslotproof_chain_id: u128,
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            satellite_contract: ContractAddress,
            // The L1 chain id to use with the satellite contract.
            chain_id: u128,
        ) {
            self.Singleslotproof_satellite_contract.write(satellite_contract);
            self.Singleslotproof_chain_id.write(chain_id);
        }

        fn get_storage_slot(
            self: @ComponentState<TContractState>,
            timestamp: u32,
            l1_contract_address: EthAddress,
            slot_key: u256,
        ) -> u256 {
            // Get the L1 block from the satellite contract.
            let l1_block_number = self.get_block_by_timestamp(timestamp);

            // Returns the value of the storage slot of account: `l1_contract_address` at key: `slot_key` and block number: `l1_block_number`.
            let slot_value = ISatelliteDispatcher {
                contract_address: self.Singleslotproof_satellite_contract.read()
            }
                .storageSlot(
                    self.Singleslotproof_chain_id.read().into(),
                    l1_block_number,
                    l1_contract_address.into(),
                    slot_key
                );

            slot_value
        }
    }

    #[embeddable_as(SingleSlotProofImpl)]
    impl SimpleQuorum<
        TContractState, +HasComponent<TContractState>
    > of ISingleSlotProof<ComponentState<TContractState>> {
        fn get_block_by_timestamp(self: @ComponentState<TContractState>, timestamp: u32) -> u256 {
            let l1_block_number = ISatelliteDispatcher {
                contract_address: self.Singleslotproof_satellite_contract.read()
            }
                .timestamp(self.Singleslotproof_chain_id.read().into(), timestamp.into());

            assert(l1_block_number.is_non_zero(), 'Received block number is zero');
            l1_block_number
        }
    }
}
