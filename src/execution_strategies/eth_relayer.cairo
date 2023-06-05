#[contract]
mod EthRelayerExecutionStrategy {
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::info::get_caller_address;
    use sx::interfaces::IExecutionStrategy;
    use sx::utils::types::{Proposal, ProposalStatus};
    use sx::execution_strategies::simple_quorum::SimpleQuorumExecutionStrategy;

    impl EthRelayerExecutionStrategy of IExecutionStrategy {
        fn execute(
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            let proposal_status = SimpleQuorumExecutionStrategy::get_proposal_status(
                @proposal, votes_for, votes_against, votes_abstain
            );
            assert(
                (proposal_status == ProposalStatus::Accepted(
                    ()
                )) | (proposal_status == ProposalStatus::VotingPeriodAccepted(())),
                'Invalid Proposal Status'
            );
            assert(
                poseidon::poseidon_hash_span(
                    payload.clone().span()
                ) == proposal.execution_payload_hash,
                'Invalid payload hash'
            );
            let space = get_caller_address();

            // Decode payload
            let l1_destination = payload[0];
            let execution_hash = u256 {
                low: payload[2],
                high: payload[1]
            };

            let mut message_payload = ArrayTrait::<felt252>::new();
            space.serialize(mut message_payload);
            execution_hash.serialize(mut message_payload);
            send_message_to_l1_syscall(
                l1_destination,
                message_payload
            );
        }
    }

    #[constructor]
    fn constructor(quorum: u256) {
        SimpleQuorumExecutionStrategy::initializer(quorum);
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