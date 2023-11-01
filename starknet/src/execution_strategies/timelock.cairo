use starknet::ContractAddress;
use sx::types::{Proposal, ProposalStatus};

#[starknet::interface]
trait ITimelockExecutionStrategy<TContractState> {
    fn execute_queued_proposal(ref self: TContractState, payload: Array<felt252>);

    fn veto(ref self: TContractState, payload_hash: felt252);

    fn set_veto_guardian(ref self: TContractState, new_veto_guardian: ContractAddress);

    fn set_timelock_delay(ref self: TContractState, new_timelock_delay: u256);
}

#[starknet::contract]
mod TimelockExecutionStrategy {
    use core::result::ResultTrait;
    use starknet::{ContractAddress, info, syscalls};
    use sx::interfaces::IExecutionStrategy;
    use super::ITimelockExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};
    use sx::utils::simple_quorum;

    #[storage]
    struct Storage {
        _quorum: u256,
        _timelock_delay: u32,
        _proposal_execution_time: LegacyMap::<felt252, u32>
    }

    #[derive(Drop, Serde, Clone)]
    struct CallWithSalt {
        to: ContractAddress,
        selector: felt252,
        calldata: Array<felt252>,
        salt: felt252
    }

    #[external(v0)]
    impl ExecutionStrategy of IExecutionStrategy<ContractState> {
        fn execute(
            ref self: ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
            payload: Array<felt252>
        ) {
            assert(
                self._proposal_execution_time.read(proposal.execution_payload_hash) == 0,
                'Duplicate Hash'
            );

            let execution_time = info::get_block_timestamp().try_into().unwrap()
                + self._timelock_delay.read();
            self._proposal_execution_time.write(proposal.execution_payload_hash, execution_time);

            let proposal_status = self
                .get_proposal_status(proposal, votes_for, votes_against, votes_abstain);
            assert(
                proposal_status == ProposalStatus::Accepted(())
                    || proposal_status == ProposalStatus::VotingPeriodAccepted(()),
                'Invalid Proposal Status'
            );

            let mut payload = payload.span();
            let mut calls = Serde::<Array<CallWithSalt>>::deserialize(ref payload).unwrap();

            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        syscalls::call_contract_syscall(
                            call.to, call.selector, call.calldata.span()
                        )
                            .expect('Call Failed');
                    },
                    Option::None(()) => {
                        break;
                    }
                };
            }
        }

        fn get_proposal_status(
            self: @ContractState,
            proposal: Proposal,
            votes_for: u256,
            votes_against: u256,
            votes_abstain: u256,
        ) -> ProposalStatus {
            simple_quorum::get_proposal_status(
                @proposal, self._quorum.read(), votes_for, votes_against, votes_abstain
            )
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'SimpleQuorumTimelock'
        }
    }
}
