#[contract]
mod EthRelayerExecutionStrategy {
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
            let payload_felt: Array<felt252> = payload.clone().into();
            assert(
                poseidon::poseidon_hash_span(
                    payload_felt.span()
                ) == proposal.execution_payload_hash,
                'Invalid payload hash'
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
        payload: Array<felt252>
    ) {
        VanillaExecutionStrategy::execute(
            proposal, votes_for, votes_against, votes_abstain, payload
        );
    }
}
