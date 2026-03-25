#[starknet::contract]
mod EvmSlotValueVotingStrategy {
    use starknet::{EthAddress, ContractAddress};
    use sx::types::{UserAddress, UserAddressTrait};
    use sx::interfaces::IVotingStrategy;
    use sx::utils::{single_slot_proof::SingleSlotProofComponent, TIntoU256};
    use sx::utils::endian::ByteReverse;

    component!(
        path: SingleSlotProofComponent, storage: single_slot_proof, event: SingleSlotProofEvent
    );

    #[abi(embed_v0)]
    impl SingleSlotProofImpl =
        SingleSlotProofComponent::SingleSlotProofImpl<ContractState>;
    impl SingleSlotProofInternalImpl = SingleSlotProofComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        single_slot_proof: SingleSlotProofComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SingleSlotProofEvent: SingleSlotProofComponent::Event
    }

    #[abi(embed_v0)]
    impl EvmSlotValueVotingStrategy of IVotingStrategy<ContractState> {
        /// Returns the value of a slot in a mapping in an EVM contract at the block number corresponding to the given timestamp.
        ///
        /// # Notes
        ///
        /// This is most often used for proving a user balance on a different chain, such as a ERC20 token balance on L1.
        ///
        /// # Arguments
        ///
        /// * `timestamp` - The timestamp of the block at which the voting power is calculated.
        /// * `voter` - The address of the voter. Expected to be an ethereum address.
        /// * `params` - Should contain the contract address and the slot index.
        /// * `_user_params` - Unused.
        ///
        /// # Returns
        ///
        /// `u256` - The slot value of the voter at the given timestamp.
        fn get_voting_power(
            self: @ContractState,
            timestamp: u32,
            voter: UserAddress,
            mut params: Span<felt252>, // [contract_address: address, slot_index: u256]
            user_params: Span<felt252>,
        ) -> u256 {
            // Cast voter address to an Ethereum address
            // Will revert if the address is not a valid Ethereum address
            let voter = voter.to_ethereum_address();

            // Decode params
            let (evm_contract_address, slot_index) = Serde::<
                (EthAddress, u256)
            >::deserialize(ref params)
                .unwrap();

            // Computes the key of the EVM storage slot from the mapping key and the index of the mapping in storage.
            let slot_key = InternalImpl::get_mapping_slot_key(voter.into(), slot_index);

            // Returns the value of the storage slot at the block number corresponding to the given timestamp.
            let slot_value = self
                .single_slot_proof
                .get_storage_slot(timestamp, evm_contract_address, slot_key);

            slot_value
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_mapping_slot_key(mapping_key: u256, slot_index: u256) -> u256 {
            keccak::keccak_u256s_be_inputs(array![mapping_key, slot_index].span()).byte_reverse()
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, satellite_contract: ContractAddress, chain_id: u128) {
        self.single_slot_proof.initializer(satellite_contract, chain_id);
    }
}

#[cfg(test)]
mod tests {
    use super::EvmSlotValueVotingStrategy;
    use sx::interfaces::{
        ISingleSlotProof, ISingleSlotProofDispatcher, ISingleSlotProofDispatcherTrait
    };
    use sx::tests::utils::single_slot_proof::deploy_satellite;

    #[test]
    #[available_gas(10000000)]
    fn ensure_ssp_is_exposed() {
        let constructor_calldata = array![deploy_satellite().into(), 11155111.into()];
        let (contract_address, _) = starknet::syscalls::deploy_syscall(
            EvmSlotValueVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
            0,
            constructor_calldata.span(),
            false,
        )
            .unwrap();

        let ssp = ISingleSlotProofDispatcher { contract_address };
        let tt = 1337;
        let block_number = ssp.get_block_by_timestamp(tt);

        assert(block_number == 1, 'Block number is not 1');
    }

    #[test]
    #[available_gas(10000000)]
    fn get_mapping_slot_key() {
        assert(
            EvmSlotValueVotingStrategy::InternalImpl::get_mapping_slot_key(
                0x0_u256, 0x0_u256
            ) == u256 {
                low: 0x2b36e491b30a40b2405849e597ba5fb5, high: 0xad3228b676f7d3cd4284a5443f17f196
            },
            'Incorrect slot key'
        );
        assert(
            EvmSlotValueVotingStrategy::InternalImpl::get_mapping_slot_key(
                0x1_u256, 0x0_u256
            ) == u256 {
                low: 0x10426056ef8ca54750cb9bb552a59e7d, high: 0xada5013122d395ba3c54772283fb069b
            },
            'Incorrect slot key'
        );
        assert(
            EvmSlotValueVotingStrategy::InternalImpl::get_mapping_slot_key(
                0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045_u256, 0x1_u256
            ) == u256 {
                low: 0xad9172e102b3af1e07a10cc29003beb2, high: 0xb931be0b3d1fb06daf0d92e2b8dfe49e
            },
            'Incorrect slot key'
        );
    }
}
