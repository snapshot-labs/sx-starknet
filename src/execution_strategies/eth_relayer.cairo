#[contract]
mod EthRelayerExecutionStrategy {
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::info::get_caller_address;
    use sx::interfaces::IExecutionStrategy;
    use sx::utils::types::{Proposal};

    impl EthRelayerExecutionStrategy of IExecutionStrategy {
        fn execute(
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

            let mut message_payload = ArrayTrait::<felt252>::new();
            space.serialize(mut message_payload);
            proposal.serialize(mut message_payload);
            votes_for.serialize(mut message_payload);
            votes_against.serialize(mut message_payload);
            votes_abstain.serialize(mut message_payload);
            execution_hash.serialize(mut message_payload);

            send_message_to_l1_syscall(l1_destination, message_payload);
        }
    }

    #[external]
    fn execute(
        proposal: Proposal,
        votes_for: u256,
        votes_against: u256,
        votes_abstain: u256,
        payload: Array<u8>
    ) {
        VanillaExecutionStrategy::execute(
            proposal, votes_for, votes_against, votes_abstain, payload
        );
    }
}
