#[starknet::contract]
mod EthRelayerExecutionStrategy {
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::info::get_caller_address;
    use sx::interfaces::IExecutionStrategy;
    use sx::types::{Proposal};

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
            let space = get_caller_address();

            // Decode payload
            let l1_destination = payload[0];
            // keccak hash of the proposal execution payload
            let execution_hash = u256 { low: payload[2], high: payload[1] };

            let mut message_payload = array![];
            space.serialize(mut message_payload);
            proposal.serialize(mut message_payload);
            votes_for.serialize(mut message_payload);
            votes_against.serialize(mut message_payload);
            votes_abstain.serialize(mut message_payload);
            execution_hash.serialize(mut message_payload);

            send_message_to_l1_syscall(l1_destination, message_payload);
        }
    }
}
