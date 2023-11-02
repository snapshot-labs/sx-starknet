use starknet::ContractAddress;
use sx::types::{Proposal, ProposalStatus};

#[starknet::interface]
trait ITimelockExecutionStrategy<TContractState> {
    fn execute_queued_proposal(ref self: TContractState, payload: Span<felt252>);

    fn veto(ref self: TContractState, execution_payload_hash: felt252);

    fn set_veto_guardian(ref self: TContractState, new_veto_guardian: ContractAddress);

    fn set_timelock_delay(ref self: TContractState, new_timelock_delay: u32);
}

#[starknet::contract]
mod TimelockExecutionStrategy {
    use starknet::{ContractAddress, info, syscalls};
    use openzeppelin::access::ownable::Ownable;
    use sx::interfaces::IExecutionStrategy;
    use super::ITimelockExecutionStrategy;
    use sx::types::{Proposal, ProposalStatus};
    use sx::utils::SimpleQuorum;

    #[storage]
    struct Storage {
        _timelock_delay: u32,
        _veto_guardian: ContractAddress,
        _proposal_execution_time: LegacyMap::<felt252, u32>
    }

    // Events

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TimelockExecutionStrategySetUp: TimelockExecutionStrategySetUp,
        TimelockDelaySet: TimelockDelaySet,
        VetoGuardianSet: VetoGuardianSet,
        CallQueued: CallQueued,
        ProposalQueued: ProposalQueued,
        CallExecuted: CallExecuted,
        ProposalExecuted: ProposalExecuted,
        ProposalVetoed: ProposalVetoed
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct TimelockExecutionStrategySetUp {
        owner: ContractAddress,
        veto_guardian: ContractAddress,
        timelock_delay: u32,
        quorum: u256
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct TimelockDelaySet {
        new_timelock_delay: u32
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct VetoGuardianSet {
        new_veto_guardian: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallQueued {
        call: CallWithSalt,
        execution_time: u32
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ProposalQueued {
        execution_payload_hash: felt252,
        execution_time: u32
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct CallExecuted {
        call: CallWithSalt
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ProposalExecuted {
        execution_payload_hash: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ProposalVetoed {
        execution_payload_hash: felt252
    }

    #[derive(Drop, PartialEq, Serde)]
    struct CallWithSalt {
        to: ContractAddress,
        selector: felt252,
        calldata: Array<felt252>,
        salt: felt252
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        veto_guardian: ContractAddress,
        timelock_delay: u32,
        quorum: u256
    ) {
        // Migration to components planned ; disregard the `unsafe` keyword,
        // it is actually safe.
        let mut state = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref state, owner);

        let mut state = SimpleQuorum::unsafe_new_contract_state();
        SimpleQuorum::InternalImpl::initializer(ref state, quorum);

        self._timelock_delay.write(timelock_delay);
        self._veto_guardian.write(veto_guardian);
    // TODO: Add spaces whitelist
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
            let state = SimpleQuorum::unsafe_new_contract_state();
            let proposal_status = SimpleQuorum::InternalImpl::get_proposal_status(
                @state, @proposal, votes_for, votes_against, votes_abstain
            );
            assert(
                proposal_status == ProposalStatus::Accepted(())
                    || proposal_status == ProposalStatus::VotingPeriodAccepted(()),
                'Invalid Proposal Status'
            );

            assert(
                self._proposal_execution_time.read(proposal.execution_payload_hash) == 0,
                'Duplicate Hash'
            );

            let execution_time = info::get_block_timestamp().try_into().unwrap()
                + self._timelock_delay.read();
            self._proposal_execution_time.write(proposal.execution_payload_hash, execution_time);

            let mut payload = payload.span();
            let mut calls = Serde::<Array<CallWithSalt>>::deserialize(ref payload).unwrap();

            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        self
                            .emit(
                                Event::CallQueued(
                                    CallQueued { call: call, execution_time: execution_time }
                                )
                            );
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
            let state = SimpleQuorum::unsafe_new_contract_state();
            SimpleQuorum::InternalImpl::get_proposal_status(
                @state, @proposal, votes_for, votes_against, votes_abstain
            )
        }

        fn get_strategy_type(self: @ContractState) -> felt252 {
            'SimpleQuorumTimelock'
        }
    }

    #[external(v0)]
    impl TimelockExecutionStrategy of ITimelockExecutionStrategy<ContractState> {
        fn execute_queued_proposal(ref self: ContractState, mut payload: Span<felt252>) {
            let execution_payload_hash = poseidon::poseidon_hash_span(payload);
            let execution_time = self._proposal_execution_time.read(execution_payload_hash);
            assert(execution_time != 0, 'Proposal Not Queued');
            assert(
                info::get_block_timestamp().try_into().unwrap() >= execution_time, 'Delay Not Met'
            );

            // Reset the execution time to 0 to prevent reentrancy.
            self._proposal_execution_time.write(execution_payload_hash, 0);

            let mut calls = Serde::<Array<CallWithSalt>>::deserialize(ref payload).unwrap();
            loop {
                match calls.pop_front() {
                    Option::Some(call) => {
                        syscalls::call_contract_syscall(
                            call.to, call.selector, call.calldata.span()
                        )
                            .expect('Call Failed');

                        self.emit(Event::CallExecuted(CallExecuted { call: call }));
                    },
                    Option::None(()) => {
                        break;
                    }
                };
            };

            self
                .emit(
                    Event::ProposalExecuted(
                        ProposalExecuted { execution_payload_hash: execution_payload_hash }
                    )
                );
        }

        fn veto(ref self: ContractState, execution_payload_hash: felt252) {
            self.assert_only_veto_guardian();
            assert(
                self._proposal_execution_time.read(execution_payload_hash) != 0,
                'Proposal Not Queued'
            );
            self._proposal_execution_time.write(execution_payload_hash, 0);
            self
                .emit(
                    Event::ProposalVetoed(
                        ProposalVetoed { execution_payload_hash: execution_payload_hash }
                    )
                );
        }

        fn set_veto_guardian(ref self: ContractState, new_veto_guardian: ContractAddress) {
            let state = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@state);
            self._veto_guardian.write(new_veto_guardian);

            self
                .emit(
                    Event::VetoGuardianSet(VetoGuardianSet { new_veto_guardian: new_veto_guardian })
                );
        }

        fn set_timelock_delay(ref self: ContractState, new_timelock_delay: u32) {
            let state = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@state);
            self._timelock_delay.write(new_timelock_delay);

            self
                .emit(
                    Event::TimelockDelaySet(
                        TimelockDelaySet { new_timelock_delay: new_timelock_delay }
                    )
                );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_veto_guardian(self: @ContractState) {
            assert(self._veto_guardian.read() == info::get_caller_address(), 'Unauthorized Caller');
        }
    }
}
