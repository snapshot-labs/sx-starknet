use core::traits::TryInto;
use core::traits::Destruct;
use starknet::{ClassHash, ContractAddress};
use sx::types::{UserAddress, Strategy, Proposal, IndexedStrategy, Choice, UpdateSettingsCalldata};

#[starknet::interface]
trait ISpace<TContractState> {
    // State 
    fn owner(self: @TContractState) -> ContractAddress;
    fn max_voting_duration(self: @TContractState) -> u32;
    fn min_voting_duration(self: @TContractState) -> u32;
    fn next_proposal_id(self: @TContractState) -> u256;
    fn voting_delay(self: @TContractState) -> u32;
    fn authenticators(self: @TContractState, account: ContractAddress) -> bool;
    fn voting_strategies(self: @TContractState, index: u8) -> Strategy;
    fn active_voting_strategies(self: @TContractState) -> u256;
    fn next_voting_strategy_index(self: @TContractState) -> u8;
    fn proposal_validation_strategy(self: @TContractState) -> Strategy;
    // #[view]
    fn vote_power(self: @TContractState, proposal_id: u256, choice: Choice) -> u256;
    // #[view]
    // fn vote_registry(proposal_id: u256, voter: ContractAddress) -> bool;
    fn proposals(self: @TContractState, proposal_id: u256) -> Proposal;
    // #[view]
    // fn get_proposal_status(proposal_id: u256) -> u8;

    // Owner Actions 
    fn update_settings(ref self: TContractState, input: UpdateSettingsCalldata);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
    // Actions 
    fn initialize(
        ref self: TContractState,
        owner: ContractAddress,
        min_voting_duration: u32,
        max_voting_duration: u32,
        voting_delay: u32,
        proposal_validation_strategy: Strategy,
        proposal_validation_strategy_metadata_URI: Array<felt252>,
        voting_strategies: Array<Strategy>,
        voting_strategy_metadata_URIs: Array<Array<felt252>>,
        authenticators: Array<ContractAddress>,
        metadata_URI: Array<felt252>,
        dao_URI: Array<felt252>,
    );
    fn propose(
        ref self: TContractState,
        author: UserAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>,
        metadata_URI: Array<felt252>,
    );
    fn vote(
        ref self: TContractState,
        voter: UserAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>,
        metadata_URI: Array<felt252>,
    );
    fn execute(ref self: TContractState, proposal_id: u256, execution_payload: Array<felt252>);
    fn update_proposal(
        ref self: TContractState,
        author: UserAddress,
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_URI: Array<felt252>,
    );
    fn cancel_proposal(ref self: TContractState, proposal_id: u256);
    fn upgrade(
        ref self: TContractState, class_hash: ClassHash, initialize_calldata: Array<felt252>
    );
}

#[starknet::contract]
mod Space {
    use super::ISpace;
    use starknet::{
        storage_access::{StorePacking, StoreUsingPacking}, ClassHash, ContractAddress, info, Store,
        syscalls
    };
    use zeroable::Zeroable;
    use array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use option::OptionTrait;
    use hash::LegacyHash;
    use traits::{Into, TryInto};
    use sx::{
        interfaces::{
            IProposalValidationStrategyDispatcher, IProposalValidationStrategyDispatcherTrait,
            IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait, IExecutionStrategyDispatcher,
            IExecutionStrategyDispatcherTrait
        },
        types::{
            UserAddress, Choice, FinalizationStatus, Strategy, IndexedStrategy, Proposal,
            PackedProposal, IndexedStrategyTrait, IndexedStrategyImpl, UpdateSettingsCalldata,
            NoUpdateTrait, NoUpdateString,
        },
        utils::{
            reinitializable::{Reinitializable}, ReinitializableImpl, bits::BitSetter,
            legacy_hash::{
                LegacyHashChoice, LegacyHashUserAddress, LegacyHashVotePower, LegacyHashVoteRegistry
            },
            constants::INITIALIZE_SELECTOR
        },
        external::ownable::Ownable
    };
    use hash::{HashStateTrait, Hash, HashStateExTrait};


    #[storage]
    struct Storage {
        _min_voting_duration: u32,
        _max_voting_duration: u32,
        _next_proposal_id: u256,
        _voting_delay: u32,
        _active_voting_strategies: u256,
        _voting_strategies: LegacyMap::<u8, Strategy>,
        _next_voting_strategy_index: u8,
        _proposal_validation_strategy: Strategy,
        _authenticators: LegacyMap::<ContractAddress, bool>,
        _proposals: LegacyMap::<u256, Proposal>,
        _vote_power: LegacyMap::<(u256, Choice), u256>,
        _vote_registry: LegacyMap::<(u256, UserAddress), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SpaceCreated: SpaceCreated,
        ProposalCreated: ProposalCreated,
        VoteCast: VoteCast,
        ProposalExecuted: ProposalExecuted,
        ProposalUpdated: ProposalUpdated,
        ProposalCancelled: ProposalCancelled,
        VotingStrategiesAdded: VotingStrategiesAdded,
        VotingStrategiesRemoved: VotingStrategiesRemoved,
        AuthenticatorsAdded: AuthenticatorsAdded,
        AuthenticatorsRemoved: AuthenticatorsRemoved,
        MetadataUriUpdated: MetadataUriUpdated,
        DaoUriUpdated: DaoUriUpdated,
        MaxVotingDurationUpdated: MaxVotingDurationUpdated,
        MinVotingDurationUpdated: MinVotingDurationUpdated,
        ProposalValidationStrategyUpdated: ProposalValidationStrategyUpdated,
        VotingDelayUpdated: VotingDelayUpdated,
        Upgraded: Upgraded,
    }

    #[derive(Drop, starknet::Event)]
    struct SpaceCreated {
        space: ContractAddress,
        owner: ContractAddress,
        min_voting_duration: u32,
        max_voting_duration: u32,
        voting_delay: u32,
        proposal_validation_strategy: Strategy,
        proposal_validation_strategy_metadata_URI: Span<felt252>,
        voting_strategies: Span<Strategy>,
        voting_strategy_metadata_URIs: Span<Array<felt252>>,
        authenticators: Span<ContractAddress>,
        metadata_URI: Span<felt252>,
        dao_URI: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        proposal_id: u256,
        author: UserAddress,
        proposal: Proposal,
        payload: Span<felt252>,
        metadata_URI: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        proposal_id: u256,
        voter: UserAddress,
        choice: Choice,
        voting_power: u256,
        metadata_URI: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalExecuted {
        proposal_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalUpdated {
        proposal_id: u256,
        execution_strategy: Strategy,
        metadata_URI: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCancelled {
        proposal_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingStrategiesAdded {
        voting_strategies: Span<Strategy>,
        voting_strategy_metadata_URIs: Span<Array<felt252>>,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingStrategiesRemoved {
        voting_strategy_indices: Span<u8>,
    }

    #[derive(Drop, starknet::Event)]
    struct AuthenticatorsAdded {
        authenticators: Span<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    struct AuthenticatorsRemoved {
        authenticators: Span<ContractAddress>,
    }

    #[derive(Drop, starknet::Event)]
    struct MaxVotingDurationUpdated {
        max_voting_duration: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct MinVotingDurationUpdated {
        min_voting_duration: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalValidationStrategyUpdated {
        proposal_validation_strategy: Strategy,
        proposal_validation_strategy_metadata_URI: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingDelayUpdated {
        voting_delay: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash,
        initialize_calldata: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct MetadataUriUpdated {
        metadata_URI: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    struct DaoUriUpdated {
        dao_URI: Span<felt252>,
    }

    #[external(v0)]
    impl Space of ISpace<ContractState> {
        fn initialize(
            ref self: ContractState,
            owner: ContractAddress,
            min_voting_duration: u32,
            max_voting_duration: u32,
            voting_delay: u32,
            proposal_validation_strategy: Strategy,
            proposal_validation_strategy_metadata_URI: Array<felt252>,
            voting_strategies: Array<Strategy>,
            voting_strategy_metadata_URIs: Array<Array<felt252>>,
            authenticators: Array<ContractAddress>,
            metadata_URI: Array<felt252>,
            dao_URI: Array<felt252>,
        ) {
            self
                .emit(
                    Event::SpaceCreated(
                        SpaceCreated {
                            space: info::get_contract_address(),
                            owner: owner,
                            min_voting_duration: min_voting_duration,
                            max_voting_duration: max_voting_duration,
                            voting_delay: voting_delay,
                            proposal_validation_strategy: proposal_validation_strategy.clone(),
                            proposal_validation_strategy_metadata_URI: proposal_validation_strategy_metadata_URI
                                .span(),
                            voting_strategies: voting_strategies.span(),
                            voting_strategy_metadata_URIs: voting_strategy_metadata_URIs.span(),
                            authenticators: authenticators.span(),
                            metadata_URI: metadata_URI.span(),
                            dao_URI: dao_URI.span()
                        }
                    )
                );

            // Checking that the contract is not already initialized
            //TODO: temporary component syntax (see imports too)
            let mut state: Reinitializable::ContractState =
                Reinitializable::unsafe_new_contract_state();
            ReinitializableImpl::initialize(ref state);

            //TODO: temporary component syntax
            let mut state = Ownable::unsafe_new_contract_state();
            Ownable::initializer(ref state);
            Ownable::transfer_ownership(ref state, owner);
            _set_max_voting_duration(
                ref self, max_voting_duration
            ); // Need to set max before min, or else `max == 0` and set_min will revert
            _set_min_voting_duration(ref self, min_voting_duration);
            _set_voting_delay(ref self, voting_delay);
            _set_proposal_validation_strategy(ref self, proposal_validation_strategy);
            _add_voting_strategies(ref self, voting_strategies.span());
            _add_authenticators(ref self, authenticators.span());
            self._next_proposal_id.write(1_u256);
        }

        fn propose(
            ref self: ContractState,
            author: UserAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>,
            metadata_URI: Array<felt252>,
        ) {
            assert_only_authenticator(@self);
            assert(author.is_non_zero(), 'Zero Address');
            let proposal_id = self._next_proposal_id.read();

            // Proposal Validation
            let proposal_validation_strategy = self._proposal_validation_strategy.read();
            let is_valid = IProposalValidationStrategyDispatcher {
                contract_address: proposal_validation_strategy.address
            }
                .validate(
                    author,
                    proposal_validation_strategy.params.span(),
                    user_proposal_validation_params.span()
                );
            assert(is_valid, 'Proposal is not valid');

            // The snapshot block timestamp is the start of the voting period
            let start_timestamp = info::get_block_timestamp().try_into().unwrap()
                + self._voting_delay.read();
            let min_end_timestamp = start_timestamp + self._min_voting_duration.read();
            let max_end_timestamp = start_timestamp + self._max_voting_duration.read();

            // TODO: we use a felt252 for the hash despite felts being discouraged 
            // a new field would just replace the hash. Might be worth casting to a Uint256 though? 
            let execution_payload_hash = poseidon::poseidon_hash_span(
                execution_strategy.params.span()
            );

            let proposal = Proposal {
                start_timestamp: start_timestamp,
                min_end_timestamp: min_end_timestamp,
                max_end_timestamp: max_end_timestamp,
                execution_payload_hash: execution_payload_hash,
                execution_strategy: execution_strategy.address,
                author: author,
                finalization_status: FinalizationStatus::Pending(()),
                active_voting_strategies: self._active_voting_strategies.read()
            };
            let clone_proposal = proposal.clone();

            // TODO: Lots of copying, maybe figure out how to pass snapshots to events/storage writers. 
            self._proposals.write(proposal_id, proposal);

            self._next_proposal_id.write(proposal_id + 1_u256);

            self
                .emit(
                    Event::ProposalCreated(
                        ProposalCreated {
                            proposal_id: proposal_id,
                            author: author,
                            proposal: clone_proposal, // TODO: use span, remove clone
                            payload: execution_strategy.params.span(),
                            metadata_URI: metadata_URI.span()
                        }
                    )
                );
        }

        fn vote(
            ref self: ContractState,
            voter: UserAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>,
            metadata_URI: Array<felt252>
        ) {
            assert_only_authenticator(@self);
            assert(voter.is_non_zero(), 'Zero Address');
            let proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);

            let timestamp = info::get_block_timestamp().try_into().unwrap();

            assert(timestamp < proposal.max_end_timestamp, 'Voting period has ended');
            assert(timestamp >= proposal.start_timestamp, 'Voting period has not started');
            assert(
                proposal.finalization_status == FinalizationStatus::Pending(()),
                'Proposal has been finalized'
            );
            assert(
                self._vote_registry.read((proposal_id, voter)) == false, 'Voter has already voted'
            );

            let voting_power = _get_cumulative_power(
                @self,
                voter,
                proposal.start_timestamp,
                user_voting_strategies.span(),
                proposal.active_voting_strategies
            );

            assert(voting_power > 0_u256, 'User has no voting power');
            self
                ._vote_power
                .write(
                    (proposal_id, choice),
                    self._vote_power.read((proposal_id, choice)) + voting_power
                );
            self._vote_registry.write((proposal_id, voter), true);

            self
                .emit(
                    Event::VoteCast(
                        VoteCast {
                            proposal_id: proposal_id,
                            voter: voter,
                            choice: choice,
                            voting_power: voting_power,
                            metadata_URI: metadata_URI.span()
                        }
                    )
                );
        }

        fn execute(ref self: ContractState, proposal_id: u256, execution_payload: Array<felt252>) {
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);

            let recovered_hash = poseidon::poseidon_hash_span(execution_payload.span());
            // Check that payload matches
            assert(recovered_hash == proposal.execution_payload_hash, 'Invalid payload hash');

            // Check that finalization status is not pending
            assert(
                proposal.finalization_status == FinalizationStatus::Pending(()), 'Already finalized'
            );

            IExecutionStrategyDispatcher { contract_address: proposal.execution_strategy }
                .execute(
                    proposal.clone(),
                    self._vote_power.read((proposal_id, Choice::For(()))),
                    self._vote_power.read((proposal_id, Choice::Against(()))),
                    self._vote_power.read((proposal_id, Choice::Abstain(()))),
                    execution_payload
                );

            proposal.finalization_status = FinalizationStatus::Executed(());

            self._proposals.write(proposal_id, proposal);

            self.emit(Event::ProposalExecuted(ProposalExecuted { proposal_id: proposal_id }));
        }

        fn update_proposal(
            ref self: ContractState,
            author: UserAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_URI: Array<felt252>,
        ) {
            assert_only_authenticator(@self);
            assert(author.is_non_zero(), 'Zero Address');
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);
            assert(proposal.author == author, 'Only Author');
            assert(
                info::get_block_timestamp() < proposal.start_timestamp.into(),
                'Voting period started'
            );

            proposal.execution_strategy = execution_strategy.address;

            proposal
                .execution_payload_hash =
                    poseidon::poseidon_hash_span(execution_strategy.params.span());

            self._proposals.write(proposal_id, proposal);

            self
                .emit(
                    Event::ProposalUpdated(
                        ProposalUpdated {
                            proposal_id: proposal_id,
                            execution_strategy: execution_strategy,
                            metadata_URI: metadata_URI.span()
                        }
                    )
                );
        }

        fn cancel_proposal(ref self: ContractState, proposal_id: u256) {
            //TODO: temporary component syntax
            let state = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);
            assert(
                proposal.finalization_status == FinalizationStatus::Pending(()), 'Already Finalized'
            );
            proposal.finalization_status = FinalizationStatus::Cancelled(());
            self._proposals.write(proposal_id, proposal);

            self.emit(Event::ProposalCancelled(ProposalCancelled { proposal_id: proposal_id }));
        }

        fn upgrade(
            ref self: ContractState, class_hash: ClassHash, initialize_calldata: Array<felt252>
        ) {
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);

            assert(class_hash.is_non_zero(), 'Class Hash cannot be zero');
            starknet::replace_class_syscall(class_hash).unwrap();

            // Allowing initializer to be called again.
            let mut state: Reinitializable::ContractState =
                Reinitializable::unsafe_new_contract_state();
            ReinitializableImpl::reinitialize(ref state);

            // Call initializer on the new version.
            syscalls::call_contract_syscall(
                info::get_contract_address(), INITIALIZE_SELECTOR, initialize_calldata.span()
            )
                .unwrap();

            self
                .emit(
                    Event::Upgraded(
                        Upgraded {
                            class_hash: class_hash, initialize_calldata: initialize_calldata.span()
                        }
                    )
                );
        }

        fn owner(self: @ContractState) -> ContractAddress {
            //TODO: temporary component syntax
            let state = Ownable::unsafe_new_contract_state();
            Ownable::owner(@state)
        }

        fn max_voting_duration(self: @ContractState) -> u32 {
            self._max_voting_duration.read()
        }

        fn min_voting_duration(self: @ContractState) -> u32 {
            self._min_voting_duration.read()
        }

        fn next_proposal_id(self: @ContractState) -> u256 {
            self._next_proposal_id.read()
        }

        fn voting_delay(self: @ContractState) -> u32 {
            self._voting_delay.read()
        }

        fn authenticators(self: @ContractState, account: ContractAddress) -> bool {
            self._authenticators.read(account)
        }

        fn voting_strategies(self: @ContractState, index: u8) -> Strategy {
            self._voting_strategies.read(index)
        }

        fn active_voting_strategies(self: @ContractState) -> u256 {
            self._active_voting_strategies.read()
        }

        fn next_voting_strategy_index(self: @ContractState) -> u8 {
            self._next_voting_strategy_index.read()
        }

        fn proposal_validation_strategy(self: @ContractState) -> Strategy {
            self._proposal_validation_strategy.read()
        }

        fn proposals(self: @ContractState, proposal_id: u256) -> Proposal {
            self._proposals.read(proposal_id)
        }

        fn update_settings(ref self: ContractState, input: UpdateSettingsCalldata) {
            //TODO: temporary component syntax
            let state = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);

            // Needed because the compiler will go crazy if we try to use `input` directly
            let _min_voting_duration = input.min_voting_duration;
            let _max_voting_duration = input.max_voting_duration;

            if _max_voting_duration.should_update() && _min_voting_duration.should_update() {
                // Check that min and max voting durations are valid
                // We don't use the internal `_set_min_voting_duration` and `_set_max_voting_duration` functions because
                // it would revert when `_min_voting_duration > max_voting_duration` (when the new `_min` is
                // bigger than the current `max`).
                assert(_min_voting_duration <= _max_voting_duration, 'Invalid duration');

                self._min_voting_duration.write(input.min_voting_duration);
                self
                    .emit(
                        Event::MinVotingDurationUpdated(
                            MinVotingDurationUpdated {
                                min_voting_duration: input.min_voting_duration
                            }
                        )
                    );

                self._max_voting_duration.write(input.max_voting_duration);
                self
                    .emit(
                        Event::MaxVotingDurationUpdated(
                            MaxVotingDurationUpdated {
                                max_voting_duration: input.max_voting_duration
                            }
                        )
                    );
            } else if _min_voting_duration.should_update() {
                _set_min_voting_duration(ref self, input.min_voting_duration);
                self
                    .emit(
                        Event::MinVotingDurationUpdated(
                            MinVotingDurationUpdated {
                                min_voting_duration: input.min_voting_duration
                            }
                        )
                    );
            } else if _max_voting_duration.should_update() {
                _set_max_voting_duration(ref self, input.max_voting_duration);
                self
                    .emit(
                        Event::MaxVotingDurationUpdated(
                            MaxVotingDurationUpdated {
                                max_voting_duration: input.max_voting_duration
                            }
                        )
                    );
            }

            if input.voting_delay.should_update() {
                _set_voting_delay(ref self, input.voting_delay);

                self
                    .emit(
                        Event::VotingDelayUpdated(
                            VotingDelayUpdated { voting_delay: input.voting_delay }
                        )
                    );
            }

            if input.proposal_validation_strategy.should_update() {
                _set_proposal_validation_strategy(
                    ref self, input.proposal_validation_strategy.clone()
                );
                self
                    .emit(
                        Event::ProposalValidationStrategyUpdated(
                            ProposalValidationStrategyUpdated {
                                proposal_validation_strategy: input
                                    .proposal_validation_strategy
                                    .clone(),
                                proposal_validation_strategy_metadata_URI: input
                                    .proposal_validation_strategy_metadata_URI
                                    .span()
                            }
                        )
                    );
            }

            if input.authenticators_to_add.should_update() {
                _add_authenticators(ref self, input.authenticators_to_add.span());
                self
                    .emit(
                        Event::AuthenticatorsAdded(
                            AuthenticatorsAdded {
                                authenticators: input.authenticators_to_add.span()
                            }
                        )
                    );
            }

            if input.authenticators_to_remove.should_update() {
                _remove_authenticators(ref self, input.authenticators_to_remove.span());
                self
                    .emit(
                        Event::AuthenticatorsRemoved(
                            AuthenticatorsRemoved {
                                authenticators: input.authenticators_to_remove.span()
                            }
                        )
                    );
            }

            if input.voting_strategies_to_add.should_update() {
                _add_voting_strategies(ref self, input.voting_strategies_to_add.span());
                self
                    .emit(
                        Event::VotingStrategiesAdded(
                            VotingStrategiesAdded {
                                voting_strategies: input.voting_strategies_to_add.span(),
                                voting_strategy_metadata_URIs: input
                                    .voting_strategies_metadata_URIs_to_add
                                    .span()
                            }
                        )
                    );
            }

            if input.voting_strategies_to_remove.should_update() {
                _remove_voting_strategies(ref self, input.voting_strategies_to_remove.span());
                self
                    .emit(
                        Event::VotingStrategiesRemoved(
                            VotingStrategiesRemoved {
                                voting_strategy_indices: input.voting_strategies_to_remove.span()
                            }
                        )
                    );
            }

            // TODO: test once #506 is merged
            if NoUpdateString::should_update((@input).metadata_URI) {
                self
                    .emit(
                        Event::MetadataUriUpdated(
                            MetadataUriUpdated { metadata_URI: input.metadata_URI.span() }
                        )
                    );
            }

            // TODO: test once #506 is merged
            if NoUpdateString::should_update((@input).dao_URI) {
                self.emit(Event::DaoUriUpdated(DaoUriUpdated { dao_URI: input.dao_URI.span() }));
            }
        }

        fn vote_power(self: @ContractState, proposal_id: u256, choice: Choice) -> u256 {
            self._vote_power.read((proposal_id, choice))
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            //TODO: temporary component syntax
            let mut state = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);
            Ownable::transfer_ownership(ref state, new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            //TODO: temporary component syntax
            let mut state = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);
            Ownable::renounce_ownership(ref state);
        }
    }

    /// 
    /// Internals
    ///

    fn assert_only_authenticator(self: @ContractState) {
        let caller: ContractAddress = info::get_caller_address();
        assert(self._authenticators.read(caller), 'Caller is not an authenticator');
    }

    fn assert_proposal_exists(proposal: @Proposal) {
        assert(!(*proposal.start_timestamp).is_zero(), 'Proposal does not exist');
    }

    fn _get_cumulative_power(
        self: @ContractState,
        voter: UserAddress,
        timestamp: u32,
        mut user_strategies: Span<IndexedStrategy>,
        allowed_strategies: u256
    ) -> u256 {
        user_strategies.assert_no_duplicate_indices();
        let mut total_voting_power = 0_u256;
        loop {
            match user_strategies.pop_front() {
                Option::Some(strategy_index) => {
                    assert(
                        allowed_strategies.is_bit_set(*strategy_index.index),
                        'Invalid strategy index'
                    );
                    let strategy = self._voting_strategies.read(*strategy_index.index);
                    total_voting_power +=
                        IVotingStrategyDispatcher { contract_address: strategy.address }
                        .get_voting_power(
                            timestamp, voter, strategy.params.span(), strategy_index.params.span()
                        );
                },
                Option::None => {
                    break;
                },
            };
        };
        total_voting_power
    }

    fn _set_max_voting_duration(ref self: ContractState, _max_voting_duration: u32) {
        assert(_max_voting_duration >= self._min_voting_duration.read(), 'Invalid duration');
        self._max_voting_duration.write(_max_voting_duration);
    }

    fn _set_min_voting_duration(ref self: ContractState, _min_voting_duration: u32) {
        assert(_min_voting_duration <= self._max_voting_duration.read(), 'Invalid duration');
        self._min_voting_duration.write(_min_voting_duration);
    }

    fn _set_voting_delay(ref self: ContractState, _voting_delay: u32) {
        self._voting_delay.write(_voting_delay);
    }

    fn _set_proposal_validation_strategy(
        ref self: ContractState, _proposal_validation_strategy: Strategy
    ) {
        self._proposal_validation_strategy.write(_proposal_validation_strategy);
    }

    fn _add_voting_strategies(ref self: ContractState, mut _voting_strategies: Span<Strategy>) {
        let mut cachedActiveVotingStrategies = self._active_voting_strategies.read();
        let mut cachedNextVotingStrategyIndex = self._next_voting_strategy_index.read();
        assert(
            cachedNextVotingStrategyIndex.into() < 256_u32 - _voting_strategies.len(),
            'Exceeds Voting Strategy Limit'
        );
        loop {
            match _voting_strategies.pop_front() {
                Option::Some(strategy) => {
                    assert(!(*strategy.address).is_zero(), 'Invalid voting strategy');
                    cachedActiveVotingStrategies.set_bit(cachedNextVotingStrategyIndex, true);
                    self._voting_strategies.write(cachedNextVotingStrategyIndex, strategy.clone());
                    cachedNextVotingStrategyIndex += 1_u8;
                },
                Option::None => {
                    break;
                },
            };
        };
        self._active_voting_strategies.write(cachedActiveVotingStrategies);
        self._next_voting_strategy_index.write(cachedNextVotingStrategyIndex);
    }

    fn _remove_voting_strategies(ref self: ContractState, mut _voting_strategies: Span<u8>) {
        let mut cachedActiveVotingStrategies = self._active_voting_strategies.read();
        loop {
            match _voting_strategies.pop_front() {
                Option::Some(index) => {
                    cachedActiveVotingStrategies.set_bit(*index, false);
                },
                Option::None => {
                    break;
                },
            };
        };

        assert(cachedActiveVotingStrategies != 0, 'No active voting strategy left');

        self._active_voting_strategies.write(cachedActiveVotingStrategies);
    }

    fn _add_authenticators(ref self: ContractState, mut _authenticators: Span<ContractAddress>) {
        loop {
            match _authenticators.pop_front() {
                Option::Some(authenticator) => {
                    self._authenticators.write(*authenticator, true);
                },
                Option::None => {
                    break;
                },
            };
        }
    }

    fn _remove_authenticators(ref self: ContractState, mut _authenticators: Span<ContractAddress>) {
        loop {
            match _authenticators.pop_front() {
                Option::Some(authenticator) => {
                    self._authenticators.write(*authenticator, false);
                },
                Option::None => {
                    break;
                },
            };
        }
    }
}

