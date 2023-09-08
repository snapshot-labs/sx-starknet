#[starknet::contract]
mod EthRelayerExecutionStrategy {
    use array::ArrayTrait;
    use option::OptionTrait;
    use traits::{Into, TryInto};
    use serde::Serde;
    use starknet::{info, syscalls, EthAddress};
    use sx::interfaces::IExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};

    #[storage]
    struct Storage {}

    /// Forwards the proposal data to the L1 execution strategy specified in the payload argument via
    /// the Starknet<->L1 bridge. Since this contract does not check who is calling it, it is the
    /// responsibility of the L1 contract to check that the caller is indeed an authorized
    /// space contract (this information is sent to the bridge).
    ///
    /// # Arguments
    ///
    /// * proposal - The proposal to execute.
    /// * votes_for - The number of votes for the proposal.
    /// * votes_against - The number of votes against the proposal.
    /// * votes_abstain - The number of votes abstaining from the proposal.
    /// * payload - An array containing the serialized L1 execution strategy address and the L1 execution hash.
    #[external(v0)]
    impl EthRelayerExecutionStrategy of IExecutionStrategy<ContractState> {
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            // We cannot have early proposal execution with this strategy because we determine the proposal status 
            // on L1 in a separate tx and therefore cannot ensure that the proposal is not still in the voting period 
            // when it is executed. 
            assert(
                info::get_block_timestamp() >= proposal.max_end_timestamp.into(),
                'Before max end timestamp'
            );

            let space = info::get_caller_address();

            // Decode payload into L1 execution strategy and L1 (keccak) execution hash
            let mut payload = payload.span();
            let (l1_execution_strategy, l1_execution_hash) = Serde::<(
                EthAddress, u256
            )>::deserialize(ref payload)
                .unwrap();

            // Serialize the payload to be sent to the L1 execution strategy
            let mut l1_payload = array![];
            space.serialize(ref l1_payload);
            proposal.serialize(ref l1_payload);
            votes_for.serialize(ref l1_payload);
            votes_against.serialize(ref l1_payload);
            votes_abstain.serialize(ref l1_payload);
            l1_execution_hash.serialize(ref l1_payload);

            syscalls::send_message_to_l1_syscall(l1_execution_strategy.into(), l1_payload.span());
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'EthRelayer'
        }

        /// Errors when called. The proposal status is only available on the L1 contract.
        fn get_proposal_status(
            self: @ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            panic_with_felt252('unimplemented');
            ProposalStatus::Cancelled(())
        }
    }
}
