use core::traits::Destruct;
use starknet::ContractAddress;
use sx::utils::types::{Strategy, Proposal, IndexedStrategy, Choice, UpdateSettingsCalldata};

#[starknet::interface]
trait ISpace<TContractState> {
    // State 
    fn owner(self: @TContractState) -> ContractAddress;
    fn max_voting_duration(self: @TContractState) -> u64;
    fn min_voting_duration(self: @TContractState) -> u64;
    fn next_proposal_id(self: @TContractState) -> u256;
    fn voting_delay(self: @TContractState) -> u64;
    fn authenticators(self: @TContractState, account: ContractAddress) -> bool;
    fn voting_strategies(self: @TContractState, index: u8) -> Strategy;
    fn active_voting_strategies(self: @TContractState) -> u256;
    fn next_voting_strategy_index(self: @TContractState) -> u8;
    fn proposal_validation_strategy(self: @TContractState) -> Strategy;
    // #[view]
    // fn vote_power(proposal_id: u256, choice: u8) -> u256;
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
    fn propose(
        ref self: TContractState,
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<felt252>
    );
    fn vote(
        ref self: TContractState,
        voter: ContractAddress,
        proposal_id: u256,
        choice: Choice,
        user_voting_strategies: Array<IndexedStrategy>
    );
    fn execute(ref self: TContractState, proposal_id: u256, execution_payload: Array<felt252>);
    fn update_proposal(
        ref self: TContractState,
        author: ContractAddress,
        proposal_id: u256,
        execution_strategy: Strategy
    );
    fn cancel_proposal(ref self: TContractState, proposal_id: u256);
}

#[starknet::contract]
mod Space {
    use super::ISpace;
    use starknet::{ContractAddress, info, StorageAccess};
    use zeroable::Zeroable;
    use array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use option::OptionTrait;
    use hash::LegacyHash;
    use traits::Into;

    use sx::interfaces::{
        IProposalValidationStrategyDispatcher, IProposalValidationStrategyDispatcherTrait,
        IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait, IExecutionStrategyDispatcher,
        IExecutionStrategyDispatcherTrait
    };
    use sx::utils::{
        types::{
            Choice, FinalizationStatus, Strategy, IndexedStrategy, Proposal, IndexedStrategyTrait,
            IndexedStrategyImpl, UpdateSettingsCalldata, NoUpdateU64, NoUpdateStrategy,
            NoUpdateArray
        },
        bits::BitSetter
    };
    use sx::external::ownable::Ownable;

    #[storage]
    struct Storage {
        _max_voting_duration: u64,
        _min_voting_duration: u64,
        _next_proposal_id: u256,
        _voting_delay: u64,
        _active_voting_strategies: u256,
        _voting_strategies: LegacyMap::<u8, Strategy>,
        _next_voting_strategy_index: u8,
        _proposal_validation_strategy: Strategy,
        _authenticators: LegacyMap::<ContractAddress, bool>,
        _proposals: LegacyMap::<u256, Proposal>,
        _vote_power: LegacyMap::<(u256, Choice), u256>,
        _vote_registry: LegacyMap::<(u256, ContractAddress), bool>,
    }

    #[event]
    fn SpaceCreated(
        _space: ContractAddress,
        _owner: ContractAddress,
        _voting_delay: u64,
        _min_voting_duration: u64,
        _max_voting_duration: u64,
        _proposal_validation_strategy: @Strategy,
        _voting_strategies: @Array<Strategy>,
        _authenticators: @Array<ContractAddress>
    ) {}

    #[event]
    fn ProposalCreated(
        _proposal_id: u256,
        _author: ContractAddress,
        _proposal: @Proposal,
        _payload: @Array<felt252>
    ) {}

    #[event]
    fn VoteCast(
        _proposal_id: u256, _voter: ContractAddress, _choice: Choice, _voting_power: u256
    ) {}

    #[event]
    fn ProposalExecuted(_proposal_id: u256) {}

    #[event]
    fn ProposalUpdated(_proposal_id: u256, _execution_stategy: @Strategy) {}

    #[event]
    fn ProposalCancelled(_proposal_id: u256) {}

    #[event]
    fn VotingStrategiesAdded(
        _new_voting_strategies: @Array<Strategy>,
        _new_voting_strategy_metadata_uris: @Array<Array<felt252>>
    ) {}

    #[event]
    fn VotingStrategiesRemoved(_voting_strategy_indices: @Array<u8>) {}

    #[event]
    fn AuthenticatorsAdded(_new_authenticators: @Array<ContractAddress>) {}

    #[event]
    fn AuthenticatorsRemoved(_authenticators: @Array<ContractAddress>) {}

    #[event]
    fn MetadataURIUpdated(_new_metadata_uri: @Array<felt252>) {}

    #[event]
    fn DaoURIUpdated(_new_dao_uri: @Array<felt252>) {}

    #[event]
    fn MaxVotingDurationUpdated(_new_max_voting_duration: u64) {}

    #[event]
    fn MinVotingDurationUpdated(_new_min_voting_duration: u64) {}

    #[event]
    fn ProposalValidationStrategyUpdated(
        _new_proposal_validation_strategy: @Strategy,
        _new_proposal_validation_strategy_metadata_URI: @Array<felt252>
    ) {}

    #[event]
    fn VotingDelayUpdated(_new_voting_delay: u64) {}

    #[external(v0)]
    impl Space of ISpace<ContractState> {
        fn propose(
            ref self: ContractState,
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<felt252>
        ) {
            assert_only_authenticator(@self);
            let proposal_id = self._next_proposal_id.read();

            // Proposal Validation
            let proposal_validation_strategy = self._proposal_validation_strategy.read();
            let is_valid = IProposalValidationStrategyDispatcher {
                contract_address: proposal_validation_strategy.address
            }
                .validate(
                    author, proposal_validation_strategy.params, user_proposal_validation_params
                );
            assert(is_valid, 'Proposal is not valid');

            let snapshot_timestamp = info::get_block_timestamp();
            let start_timestamp = snapshot_timestamp + self._voting_delay.read();
            let min_end_timestamp = start_timestamp + self._min_voting_duration.read();
            let max_end_timestamp = start_timestamp + self._max_voting_duration.read();

            // TODO: we use a felt252 for the hash despite felts being discouraged 
            // a new field would just replace the hash. Might be worth casting to a Uint256 though? 
            let execution_payload_hash = poseidon::poseidon_hash_span(
                execution_strategy.params.span()
            );

            let proposal = Proposal {
                snapshot_timestamp: snapshot_timestamp,
                start_timestamp: start_timestamp,
                min_end_timestamp: min_end_timestamp,
                max_end_timestamp: max_end_timestamp,
                execution_payload_hash: execution_payload_hash,
                execution_strategy: execution_strategy.address,
                author: author,
                finalization_status: FinalizationStatus::Pending(()),
                active_voting_strategies: self._active_voting_strategies.read()
            };
            let snap_proposal = @proposal;

            // TODO: Lots of copying, maybe figure out how to pass snapshots to events/storage writers. 
            self._proposals.write(proposal_id, proposal);

            self._next_proposal_id.write(proposal_id + u256 { low: 1_u128, high: 0_u128 });

            ProposalCreated(proposal_id, author, snap_proposal, @execution_strategy.params);
        }

        fn vote(
            ref self: ContractState,
            voter: ContractAddress,
            proposal_id: u256,
            choice: Choice,
            user_voting_strategies: Array<IndexedStrategy>
        ) {
            assert_only_authenticator(@self);
            let proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);

            let timestamp = info::get_block_timestamp();

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
                proposal.snapshot_timestamp,
                user_voting_strategies,
                proposal.active_voting_strategies
            );

            assert(voting_power > u256 { low: 0_u128, high: 0_u128 }, 'User has no voting power');
            self
                ._vote_power
                .write(
                    (proposal_id, choice),
                    self._vote_power.read((proposal_id, choice)) + voting_power
                );
            self._vote_registry.write((proposal_id, voter), true);

            VoteCast(proposal_id, voter, choice, voting_power);
        }

        fn execute(ref self: ContractState, proposal_id: u256, execution_payload: Array<felt252>) {
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);

            IExecutionStrategyDispatcher {
                contract_address: proposal.execution_strategy
            }
                .execute(
                    proposal.clone(),
                    self._vote_power.read((proposal_id, Choice::For(()))),
                    self._vote_power.read((proposal_id, Choice::Against(()))),
                    self._vote_power.read((proposal_id, Choice::Abstain(()))),
                    execution_payload
                );

            proposal.finalization_status = FinalizationStatus::Executed(());

            self._proposals.write(proposal_id, proposal);

            ProposalExecuted(proposal_id);
        }

        fn update_proposal(
            ref self: ContractState,
            author: ContractAddress,
            proposal_id: u256,
            execution_strategy: Strategy
        ) {
            assert_only_authenticator(@self);
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);
            assert(proposal.author == author, 'Only Author');
            assert(info::get_block_timestamp() < proposal.start_timestamp, 'Voting period started');

            proposal.execution_strategy = execution_strategy.address;

            proposal
                .execution_payload_hash =
                    poseidon::poseidon_hash_span(execution_strategy.clone().params.span());

            self._proposals.write(proposal_id, proposal);

            ProposalUpdated(proposal_id, @execution_strategy);
        }

        fn cancel_proposal(ref self: ContractState, proposal_id: u256) {
            //TODO: temporary component syntax
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);
            assert(
                proposal.finalization_status == FinalizationStatus::Pending(()), 'Already Finalized'
            );
            proposal.finalization_status = FinalizationStatus::Cancelled(());
            self._proposals.write(proposal_id, proposal);
            ProposalCancelled(proposal_id);
        }

        fn owner(self: @ContractState) -> ContractAddress {
            //TODO: temporary component syntax
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::owner(@state)
        }

        fn max_voting_duration(self: @ContractState) -> u64 {
            self._max_voting_duration.read()
        }

        fn min_voting_duration(self: @ContractState) -> u64 {
            self._min_voting_duration.read()
        }

        fn next_proposal_id(self: @ContractState) -> u256 {
            self._next_proposal_id.read()
        }

        fn voting_delay(self: @ContractState) -> u64 {
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
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);

            // if not NO_UPDATE
            if NoUpdateU64::should_update(@input.max_voting_duration) {
                _set_max_voting_duration(ref self, input.max_voting_duration);
                MaxVotingDurationUpdated(input.max_voting_duration);
            }

            if NoUpdateU64::should_update(@input.min_voting_duration) {
                _set_min_voting_duration(ref self, input.min_voting_duration);
                MinVotingDurationUpdated(input.min_voting_duration);
            }

            if NoUpdateU64::should_update(@input.voting_delay) {
                _set_voting_delay(ref self, input.voting_delay);
                VotingDelayUpdated(input.voting_delay);
            }

            if NoUpdateArray::should_update((@input).metadata_URI) {
                MetadataURIUpdated(@input.metadata_URI);
            }

            if NoUpdateArray::should_update((@input).dao_URI) {
                DaoURIUpdated(@input.dao_URI);
            }

            // if not NO_UPDATE
            if NoUpdateStrategy::should_update((@input).proposal_validation_strategy) {
                // TODO: might be possible to remove need to clone by defining the event or setter on a snapshot.
                // Similarly for all non value types.
                _set_proposal_validation_strategy(
                    ref self, input.proposal_validation_strategy.clone()
                );
                ProposalValidationStrategyUpdated(
                    @input.proposal_validation_strategy,
                    @input.proposal_validation_strategy_metadata_URI
                );
            }

            if NoUpdateArray::should_update((@input).authenticators_to_add) {
                _add_authenticators(ref self, input.authenticators_to_add.clone());
                AuthenticatorsAdded(@input.authenticators_to_add);
            }

            // if not NO_UPDATE
            if NoUpdateArray::should_update((@input).authenticators_to_remove) {
                _remove_authenticators(ref self, input.authenticators_to_remove.clone());
                AuthenticatorsRemoved(@input.authenticators_to_remove);
            }

            // if not NO_UPDATE
            if NoUpdateArray::should_update((@input).voting_strategies_to_add) {
                _add_voting_strategies(ref self, input.voting_strategies_to_add.clone());
                VotingStrategiesAdded(
                    @input.voting_strategies_to_add, @input.voting_strategies_metadata_URIs_to_add
                );
            }

            // if not NO_UPDATE
            if NoUpdateArray::should_update((@input).voting_strategies_to_remove) {
                _remove_voting_strategies(ref self, input.voting_strategies_to_remove.clone());
                VotingStrategiesRemoved(@input.voting_strategies_to_remove);
            }
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            //TODO: temporary component syntax
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);
            Ownable::transfer_ownership(ref state, new_owner);
        }

        fn renounce_ownership(ref self: ContractState) {
            //TODO: temporary component syntax
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);
            Ownable::renounce_ownership(ref state);
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _owner: ContractAddress,
        _max_voting_duration: u64,
        _min_voting_duration: u64,
        _voting_delay: u64,
        _proposal_validation_strategy: Strategy,
        _voting_strategies: Array<Strategy>,
        _authenticators: Array<ContractAddress>,
    ) {
        //TODO: temporary component syntax
        let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
        Ownable::initializer(ref state);
        Ownable::transfer_ownership(ref state, _owner);
        _set_max_voting_duration(ref self, _max_voting_duration);
        _set_min_voting_duration(ref self, _min_voting_duration);
        _set_voting_delay(ref self, _voting_delay);
        _set_proposal_validation_strategy(ref self, _proposal_validation_strategy.clone());
        _add_voting_strategies(ref self, _voting_strategies.clone());
        _add_authenticators(ref self, _authenticators.clone());
        self._next_proposal_id.write(u256 { low: 1_u128, high: 0_u128 });
        SpaceCreated(
            info::get_contract_address(),
            _owner,
            _voting_delay,
            _min_voting_duration,
            _max_voting_duration,
            @_proposal_validation_strategy,
            @_voting_strategies,
            @_authenticators
        );
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
        voter: ContractAddress,
        timestamp: u64,
        user_strategies: Array<IndexedStrategy>,
        allowed_strategies: u256
    ) -> u256 {
        user_strategies.assert_no_duplicate_indices();
        let mut total_voting_power = u256 { low: 0_u128, high: 0_u128 };
        let mut i = 0_usize;
        loop {
            if i >= user_strategies.len() {
                break ();
            }
            let strategy_index = user_strategies.at(i).index;
            assert(allowed_strategies.is_bit_set(*strategy_index), 'Invalid strategy index');
            let strategy = self._voting_strategies.read(*strategy_index);
            total_voting_power += IVotingStrategyDispatcher {
                contract_address: strategy.address
            }
                .get_voting_power(
                    timestamp, voter, strategy.params, user_strategies.at(i).params.clone()
                );
            i += 1;
        };
        total_voting_power
    }

    fn _set_max_voting_duration(ref self: ContractState, _max_voting_duration: u64) {
        self._max_voting_duration.write(_max_voting_duration);
    }

    fn _set_min_voting_duration(ref self: ContractState, _min_voting_duration: u64) {
        self._min_voting_duration.write(_min_voting_duration);
    }

    fn _set_voting_delay(ref self: ContractState, _voting_delay: u64) {
        self._voting_delay.write(_voting_delay);
    }

    fn _set_proposal_validation_strategy(
        ref self: ContractState, _proposal_validation_strategy: Strategy
    ) {
        self._proposal_validation_strategy.write(_proposal_validation_strategy);
    }

    fn _add_voting_strategies(ref self: ContractState, _voting_strategies: Array<Strategy>) {
        let mut cachedActiveVotingStrategies = self._active_voting_strategies.read();
        let mut cachedNextVotingStrategyIndex = self._next_voting_strategy_index.read();
        assert(
            cachedNextVotingStrategyIndex.into() < 256_u32 - _voting_strategies.len(),
            'Exceeds Voting Strategy Limit'
        );
        let mut _voting_strategies_span = _voting_strategies.span();
        let mut i = 0_usize;
        loop {
            if i >= _voting_strategies.len() {
                break ();
            }

            let strategy = _voting_strategies_span.pop_front().unwrap().clone();
            assert(!strategy.address.is_zero(), 'Invalid voting strategy');
            cachedActiveVotingStrategies.set_bit(cachedNextVotingStrategyIndex, true);
            self._voting_strategies.write(cachedNextVotingStrategyIndex, strategy);
            cachedNextVotingStrategyIndex += 1_u8;
            i += 1;
        };
        self._active_voting_strategies.write(cachedActiveVotingStrategies);
        self._next_voting_strategy_index.write(cachedNextVotingStrategyIndex);
    }

    fn _remove_voting_strategies(ref self: ContractState, _voting_strategies: Array<u8>) {
        let mut cachedActiveVotingStrategies = self._active_voting_strategies.read();
        let mut _voting_strategies_span = _voting_strategies.span();
        let mut i = 0_usize;
        loop {
            if i >= _voting_strategies.len() {
                break ();
            }

            let index = _voting_strategies_span.pop_front().unwrap();
            cachedActiveVotingStrategies.set_bit(*index, false);
            i += 1;
        };

        if cachedActiveVotingStrategies == 0 {
            panic_with_felt252('No active voting strategy left');
        }

        self._active_voting_strategies.write(cachedActiveVotingStrategies);
    }

    fn _add_authenticators(ref self: ContractState, _authenticators: Array<ContractAddress>) {
        let mut _authenticators_span = _authenticators.span();
        let mut i = 0_usize;
        loop {
            if i >= _authenticators.len() {
                break ();
            }
            self._authenticators.write(*_authenticators_span.pop_front().unwrap(), true);
            i += 1;
        }
    }

    fn _remove_authenticators(ref self: ContractState, _authenticators: Array<ContractAddress>) {
        let mut _authenticators_span = _authenticators.span();
        let mut i = 0_usize;
        loop {
            if i >= _authenticators.len() {
                break ();
            }
            self._authenticators.write(*_authenticators_span.pop_front().unwrap(), false);
            i += 1;
        }
    }
}

