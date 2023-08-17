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
    use starknet::{ClassHash, ContractAddress, info, Store, syscalls};
    use zeroable::Zeroable;
    use array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use option::OptionTrait;
    use hash::LegacyHash;
    use traits::{Into, TryInto};

    use sx::interfaces::{
        IProposalValidationStrategyDispatcher, IProposalValidationStrategyDispatcherTrait,
        IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait, IExecutionStrategyDispatcher,
        IExecutionStrategyDispatcherTrait
    };
    use sx::types::{
        UserAddress, Choice, FinalizationStatus, Strategy, IndexedStrategy, Proposal,
        IndexedStrategyTrait, IndexedStrategyImpl, UpdateSettingsCalldata, NoUpdateU32,
        NoUpdateStrategy, NoUpdateArray
    };
    use sx::utils::reinitializable::Reinitializable;
    use sx::utils::ReinitializableImpl;
    use sx::utils::bits::BitSetter;
    use sx::utils::legacy_hash::LegacyHashChoice;
    use sx::external::ownable::Ownable;
    use sx::utils::constants::INITIALIZE_SELECTOR;

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
    fn SpaceCreated(
        _space: ContractAddress,
        _owner: ContractAddress,
        _min_voting_duration: u32,
        _max_voting_duration: u32,
        _voting_delay: u32,
        _proposal_validation_strategy: @Strategy,
        _proposal_validation_strategy_metadata_URI: @Array<felt252>,
        _voting_strategies: @Array<Strategy>,
        _voting_strategy_metadata_URIs: @Array<Array<felt252>>,
        _authenticators: @Array<ContractAddress>,
        _metadata_URI: @Array<felt252>,
        _dao_URI: @Array<felt252>,
    ) {}

    #[event]
    fn ProposalCreated(
        _proposal_id: u256,
        _author: UserAddress,
        _proposal: @Proposal,
        _payload: @Array<felt252>,
        _metadata_URI: @Array<felt252>
    ) {}

    #[event]
    fn VoteCast(
        _proposal_id: u256,
        _voter: UserAddress,
        _choice: Choice,
        _voting_power: u256,
        _metadata_URI: @Array<felt252>
    ) {}

    #[event]
    fn ProposalExecuted(_proposal_id: u256) {}

    #[event]
    fn ProposalUpdated(
        _proposal_id: u256, _execution_stategy: @Strategy, _metadata_URI: @Array<felt252>
    ) {}

    #[event]
    fn ProposalCancelled(_proposal_id: u256) {}

    #[event]
    fn VotingStrategiesAdded(
        _new_voting_strategies: @Array<Strategy>,
        _new_voting_strategy_metadata_URIs: @Array<Array<felt252>>
    ) {}

    #[event]
    fn VotingStrategiesRemoved(_voting_strategy_indices: @Array<u8>) {}

    #[event]
    fn AuthenticatorsAdded(_new_authenticators: @Array<ContractAddress>) {}

    #[event]
    fn AuthenticatorsRemoved(_authenticators: @Array<ContractAddress>) {}

    #[event]
    fn MetadataURIUpdated(_new_metadata_URI: @Array<felt252>) {}

    #[event]
    fn DaoURIUpdated(_new_dao_URI: @Array<felt252>) {}

    #[event]
    fn MaxVotingDurationUpdated(_new_max_voting_duration: u32) {}

    #[event]
    fn MinVotingDurationUpdated(_new_min_voting_duration: u32) {}

    #[event]
    fn ProposalValidationStrategyUpdated(
        _new_proposal_validation_strategy: @Strategy,
        _new_proposal_validation_strategy_metadata_URI: @Array<felt252>
    ) {}

    #[event]
    fn VotingDelayUpdated(_new_voting_delay: u32) {}

    #[event]
    fn Upgraded(class_hash: ClassHash) {}

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
            SpaceCreated(
                info::get_contract_address(),
                owner,
                min_voting_duration,
                max_voting_duration,
                voting_delay,
                @proposal_validation_strategy,
                @proposal_validation_strategy_metadata_URI,
                @voting_strategies,
                @voting_strategy_metadata_URIs,
                @authenticators,
                @metadata_URI,
                @dao_URI
            );
            // Checking that the contract is not already initialized
            //TODO: temporary component syntax (see imports too)
            let mut state: Reinitializable::ContractState =
                Reinitializable::unsafe_new_contract_state();
            ReinitializableImpl::initialize(ref state);

            //TODO: temporary component syntax
            let mut state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::initializer(ref state);
            Ownable::transfer_ownership(ref state, owner);
            _set_min_voting_duration(ref self, min_voting_duration);
            _set_max_voting_duration(ref self, max_voting_duration);
            _set_voting_delay(ref self, voting_delay);
            _set_proposal_validation_strategy(ref self, proposal_validation_strategy);
            _add_voting_strategies(ref self, voting_strategies);
            _add_authenticators(ref self, authenticators);
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

            // The snapshot block number is the start of the voting period
            let start_block_number = info::get_block_number().try_into().unwrap()
                + self._voting_delay.read();
            let min_end_block_number = start_block_number + self._min_voting_duration.read();
            let max_end_block_number = start_block_number + self._max_voting_duration.read();

            // TODO: we use a felt252 for the hash despite felts being discouraged 
            // a new field would just replace the hash. Might be worth casting to a Uint256 though? 
            let execution_payload_hash = poseidon::poseidon_hash_span(
                execution_strategy.params.span()
            );

            let proposal = Proposal {
                start_block_number: start_block_number,
                min_end_block_number: min_end_block_number,
                max_end_block_number: max_end_block_number,
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

            ProposalCreated(
                proposal_id, author, snap_proposal, @execution_strategy.params, @metadata_URI
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
            let proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);

            let block_number = info::get_block_number().try_into().unwrap();

            assert(block_number < proposal.max_end_block_number, 'Voting period has ended');
            assert(block_number >= proposal.start_block_number, 'Voting period has not started');
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
                proposal.start_block_number,
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

            VoteCast(proposal_id, voter, choice, voting_power, @metadata_URI);
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
            author: UserAddress,
            proposal_id: u256,
            execution_strategy: Strategy,
            metadata_URI: Array<felt252>,
        ) {
            assert_only_authenticator(@self);
            let mut proposal = self._proposals.read(proposal_id);
            assert_proposal_exists(@proposal);
            assert(proposal.author == author, 'Only Author');
            assert(
                info::get_block_number() < proposal.start_block_number.into(),
                'Voting period started'
            );

            proposal.execution_strategy = execution_strategy.address;

            proposal
                .execution_payload_hash =
                    poseidon::poseidon_hash_span(execution_strategy.clone().params.span());

            self._proposals.write(proposal_id, proposal);

            ProposalUpdated(proposal_id, @execution_strategy, @metadata_URI);
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

        fn upgrade(
            ref self: ContractState, class_hash: ClassHash, initialize_calldata: Array<felt252>
        ) {
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);

            assert(class_hash.is_non_zero(), 'Class Hash cannot be zero');
            starknet::replace_class_syscall(class_hash).unwrap_syscall();

            // Allowing initializer to be called again.
            let mut state: Reinitializable::ContractState =
                Reinitializable::unsafe_new_contract_state();
            ReinitializableImpl::reinitialize(ref state);

            // Call initializer on the new version.
            syscalls::call_contract_syscall(
                info::get_contract_address(), INITIALIZE_SELECTOR, initialize_calldata.span()
            )
                .unwrap_syscall();
            Upgraded(class_hash);
        }

        fn owner(self: @ContractState) -> ContractAddress {
            //TODO: temporary component syntax
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
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
            let state: Ownable::ContractState = Ownable::unsafe_new_contract_state();
            Ownable::assert_only_owner(@state);

            // if not NO_UPDATE
            if NoUpdateU32::should_update(@input.max_voting_duration) {
                _set_max_voting_duration(ref self, input.max_voting_duration);
                MaxVotingDurationUpdated(input.max_voting_duration);
            }

            if NoUpdateU32::should_update(@input.min_voting_duration) {
                _set_min_voting_duration(ref self, input.min_voting_duration);
                MinVotingDurationUpdated(input.min_voting_duration);
            }

            if NoUpdateU32::should_update(@input.voting_delay) {
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

    /// 
    /// Internals
    ///

    fn assert_only_authenticator(self: @ContractState) {
        let caller: ContractAddress = info::get_caller_address();
        assert(self._authenticators.read(caller), 'Caller is not an authenticator');
    }

    fn assert_proposal_exists(proposal: @Proposal) {
        assert(!(*proposal.start_block_number).is_zero(), 'Proposal does not exist');
    }

    fn _get_cumulative_power(
        self: @ContractState,
        voter: UserAddress,
        block_number: u32,
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
                    block_number, voter, strategy.params, user_strategies.at(i).params.clone()
                );
            i += 1;
        };
        total_voting_power
    }

    fn _set_max_voting_duration(ref self: ContractState, _max_voting_duration: u32) {
        self._max_voting_duration.write(_max_voting_duration);
    }

    fn _set_min_voting_duration(ref self: ContractState, _min_voting_duration: u32) {
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

