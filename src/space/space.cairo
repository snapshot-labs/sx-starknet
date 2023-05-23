use starknet::ContractAddress;
use sx::utils::types::{Strategy, Proposal, IndexedStrategy};

#[abi]
trait ISpace {
    // State 
    #[view]
    fn owner() -> ContractAddress;
    #[view]
    fn max_voting_duration() -> u64;
    #[view]
    fn min_voting_duration() -> u64;
    #[view]
    fn next_proposal_id() -> u256;
    #[view]
    fn voting_delay() -> u64;
    #[view]
    fn authenticators(account: ContractAddress) -> bool;
    #[view]
    fn voting_strategies(index: u8) -> Strategy;
    #[view]
    fn active_voting_strategies() -> u256;
    #[view]
    fn next_voting_strategy_index() -> u8;
    #[view]
    fn proposal_validation_strategy() -> Strategy;
    // #[view]
    // fn vote_power(proposal_id: u256, choice: u8) -> u256;
    // #[view]
    // fn vote_registry(proposal_id: u256, voter: ContractAddress) -> bool;
    #[view]
    fn proposals(proposal_id: u256) -> Proposal;
    // #[view]
    // fn get_proposal_status(proposal_id: u256) -> u8;

    // Owner Actions 
    #[external]
    fn set_max_voting_duration(max_voting_duration: u64);
    #[external]
    fn set_min_voting_duration(min_voting_duration: u64);
    #[external]
    fn set_voting_delay(voting_delay: u64);
    #[external]
    fn set_proposal_validation_strategy(proposal_validation_strategy: Strategy);
    #[external]
    fn add_voting_strategies(voting_strategies: Array<Strategy>);
    #[external]
    fn remove_voting_strategies(voting_strategy_indices: Array<u8>);
    #[external]
    fn add_authenticators(authenticators: Array<ContractAddress>);
    #[external]
    fn remove_authenticators(authenticators: Array<ContractAddress>);
    #[external]
    fn transfer_ownership(new_owner: ContractAddress);
    #[external]
    fn renounce_ownership();
    // Actions 
    #[external]
    fn propose(
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<u8>
    );
    #[external]
    fn vote(
        voter: ContractAddress,
        proposal_id: u256,
        choice: u8,
        userVotingStrategies: Array<IndexedStrategy>
    );
}

#[contract]
mod Space {
    use super::ISpace;
    use starknet::{ContractAddress, info};
    use zeroable::Zeroable;
    use array::{ArrayTrait, SpanTrait};
    use clone::Clone;
    use option::OptionTrait;
    use hash::LegacyHash;
    use traits::Into;

    use sx::interfaces::{
        IProposalValidationStrategyDispatcher, IProposalValidationStrategyDispatcherTrait,
        IVotingStrategyDispatcher, IVotingStrategyDispatcherTrait
    };
    use sx::utils::{
        types::{
        Strategy, IndexedStrategy, Proposal, U8ArrayIntoFelt252Array
        }, bits::BitSetter, math::U64Zeroable
    };
    use sx::external::ownable::Ownable;

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
        _vote_power: LegacyMap::<(u256, u8), u256>, // TODO: choice enum
        _vote_registry: LegacyMap::<(u256, ContractAddress), bool>,
    }

    #[event]
    fn SpaceCreated(
        _space: ContractAddress,
        _owner: ContractAddress,
        _voting_delay: u64,
        _min_voting_duration: u64,
        _max_voting_duration: u64,
        _proposal_validation_strategy: Strategy,
        _voting_strategies: Array<Strategy>,
        _authenticators: Array<ContractAddress>
    ) {}

    #[event]
    fn ProposalCreated(
        _proposal_id: u256, _author: ContractAddress, _proposal: Proposal, _payload: Array<u8>
    ) {}

    fn VotingStrategiesAdded(_new_voting_strategies: Array<Strategy>) {}

    #[event]
    fn VotingStrategiesRemoved(_voting_strategy_indices: Array<u8>) {}

    #[event]
    fn AuthenticatorsAdded(_new_authenticators: Array<ContractAddress>) {}

    #[event]
    fn AuthenticatorsRemoved(_authenticators: Array<ContractAddress>) {}

    #[event]
    fn MaxVotingDurationUpdated(_new_max_voting_duration: u64) {}

    #[event]
    fn MinVotingDurationUpdated(_new_min_voting_duration: u64) {}

    #[event]
    fn ProposalValidationStrategyUpdated(_new_proposal_validation_strategy: Strategy) {}

    #[event]
    fn VotingDelayUpdated(_new_voting_delay: u64) {}

    impl Space of ISpace {
        fn propose(
            author: ContractAddress,
            execution_strategy: Strategy,
            user_proposal_validation_params: Array<u8>
        ) {
            assert_only_authenticator();
            let proposal_id = _next_proposal_id::read();

            // Proposal Validation
            let proposal_validation_strategy = _proposal_validation_strategy::read();
            let valid = IProposalValidationStrategyDispatcher {
                contract_address: proposal_validation_strategy.address
            }.validate(
                author, proposal_validation_strategy.params, user_proposal_validation_params
            );
            assert(valid, 'Proposal is not valid');

            let snapshot_timestamp = info::get_block_timestamp();
            let min_end_timestamp = snapshot_timestamp + _min_voting_duration::read();
            let max_end_timestamp = snapshot_timestamp + _max_voting_duration::read();

            // Casting execution params array from u8 to felt and hashing
            let params_felt: Array<felt252> = execution_strategy.clone().params.into();
            // TODO: we use a felt252 for the hash despite felts being discouraged 
            // a new field would just replace the hash. Might be worth casting to a Uint256 though? 
            let execution_payload_hash = poseidon::poseidon_hash_span(params_felt.span());

            let proposal = Proposal {
                snapshot_timestamp: snapshot_timestamp,
                start_timestamp: snapshot_timestamp + _voting_delay::read(),
                min_end_timestamp: min_end_timestamp,
                max_end_timestamp: max_end_timestamp,
                execution_payload_hash: execution_payload_hash,
                execution_strategy: execution_strategy.address,
                author: author,
                finalization_status: 0_u8,
                active_voting_strategies: _active_voting_strategies::read()
            };

            // TODO: Lots of copying, maybe figure out how to pass snapshots to events/storage writers. 
            _proposals::write(proposal_id, proposal.clone());

            _next_proposal_id::write(proposal_id + u256 { low: 1_u128, high: 0_u128 });

            ProposalCreated(proposal_id, author, proposal, execution_strategy.params);
        }

        fn vote(
            voter: ContractAddress,
            proposal_id: u256,
            choice: u8,
            userVotingStrategies: Array<IndexedStrategy>
        ) {
            assert_only_authenticator();
            let proposal = _proposals::read(proposal_id);
            assert_proposal_exists(@proposal);

            let timestamp = info::get_block_timestamp();

            assert(timestamp < proposal.max_end_timestamp, 'Voting period has ended');
            assert(timestamp >= proposal.start_timestamp, 'Voting period has not started');
            assert(proposal.finalization_status == 0_u8, 'Proposal has been finalized');
            assert(_vote_registry::read((proposal_id, voter)) == false, 'Voter has already voted');

            let voting_power = _get_cumulative_power(
                voter,
                proposal.snapshot_timestamp,
                userVotingStrategies,
                proposal.active_voting_strategies
            );
        }

        fn owner() -> ContractAddress {
            Ownable::owner()
        }

        fn max_voting_duration() -> u64 {
            _max_voting_duration::read()
        }

        fn min_voting_duration() -> u64 {
            _min_voting_duration::read()
        }

        fn next_proposal_id() -> u256 {
            _next_proposal_id::read()
        }

        fn voting_delay() -> u64 {
            _voting_delay::read()
        }

        fn authenticators(account: ContractAddress) -> bool {
            _authenticators::read(account)
        }

        fn voting_strategies(index: u8) -> Strategy {
            _voting_strategies::read(index)
        }

        fn active_voting_strategies() -> u256 {
            _active_voting_strategies::read()
        }

        fn next_voting_strategy_index() -> u8 {
            _next_voting_strategy_index::read()
        }

        fn proposal_validation_strategy() -> Strategy {
            _proposal_validation_strategy::read()
        }


        fn proposals(proposal_id: u256) -> Proposal {
            _proposals::read(proposal_id)
        }

        fn set_max_voting_duration(max_voting_duration: u64) {
            Ownable::assert_only_owner();
            _set_max_voting_duration(max_voting_duration);
            MaxVotingDurationUpdated(max_voting_duration);
        }

        fn set_min_voting_duration(min_voting_duration: u64) {
            Ownable::assert_only_owner();
            _set_min_voting_duration(min_voting_duration);
            MinVotingDurationUpdated(min_voting_duration);
        }

        fn set_voting_delay(voting_delay: u64) {
            Ownable::assert_only_owner();
            _set_voting_delay(voting_delay);
            VotingDelayUpdated(voting_delay);
        }

        fn set_proposal_validation_strategy(proposal_validation_strategy: Strategy) {
            Ownable::assert_only_owner();
            // TODO: might be possible to remove need to clone by defining the event or setter on a snapshot.
            // Similarly for all non value types.
            _set_proposal_validation_strategy(proposal_validation_strategy.clone());
            ProposalValidationStrategyUpdated(proposal_validation_strategy);
        }

        fn add_voting_strategies(voting_strategies: Array<Strategy>) {
            Ownable::assert_only_owner();
            _add_voting_strategies(voting_strategies.clone());
            VotingStrategiesAdded(voting_strategies);
        }

        fn remove_voting_strategies(voting_strategy_indices: Array<u8>) {
            Ownable::assert_only_owner();
        // TODO: impl once we have set_bit to false
        }

        fn add_authenticators(authenticators: Array<ContractAddress>) {
            Ownable::assert_only_owner();
            _add_authenticators(authenticators.clone());
            AuthenticatorsAdded(authenticators);
        }

        fn remove_authenticators(authenticators: Array<ContractAddress>) {
            Ownable::assert_only_owner();
            _remove_authenticators(authenticators.clone());
            AuthenticatorsRemoved(authenticators);
        }

        fn transfer_ownership(new_owner: ContractAddress) {
            Ownable::assert_only_owner();
            Ownable::transfer_ownership(new_owner);
        }

        fn renounce_ownership() {
            Ownable::assert_only_owner();
            Ownable::renounce_ownership();
        }
    }

    #[constructor]
    fn constructor(
        _owner: ContractAddress,
        _max_voting_duration: u64,
        _min_voting_duration: u64,
        _voting_delay: u64,
        _proposal_validation_strategy: Strategy,
        _voting_strategies: Array<Strategy>,
        _authenticators: Array<ContractAddress>,
    ) {
        Ownable::initializer();
        Ownable::transfer_ownership(_owner);
        _set_max_voting_duration(_max_voting_duration);
        _set_min_voting_duration(_min_voting_duration);
        _set_voting_delay(_voting_delay);
        _set_proposal_validation_strategy(_proposal_validation_strategy.clone());
        _add_voting_strategies(_voting_strategies.clone());
        _add_authenticators(_authenticators.clone());
        _next_proposal_id::write(u256 { low: 1_u128, high: 0_u128 });
        SpaceCreated(
            info::get_contract_address(),
            _owner,
            _voting_delay,
            _min_voting_duration,
            _max_voting_duration,
            _proposal_validation_strategy,
            _voting_strategies,
            _authenticators
        );
    }

    #[external]
    fn propose(
        author: ContractAddress,
        execution_strategy: Strategy,
        user_proposal_validation_params: Array<u8>
    ) {
        Space::propose(author, execution_strategy, user_proposal_validation_params);
    }

    #[external]
    fn vote(
        voter: ContractAddress,
        proposal_id: u256,
        choice: u8,
        userVotingStrategies: Array<IndexedStrategy>
    ) {
        Space::vote(voter, proposal_id, choice, userVotingStrategies);
    }

    #[view]
    fn owner() -> ContractAddress {
        Space::owner()
    }

    #[view]
    fn max_voting_duration() -> u64 {
        Space::max_voting_duration()
    }

    #[view]
    fn min_voting_duration() -> u64 {
        Space::min_voting_duration()
    }

    #[view]
    fn next_proposal_id() -> u256 {
        Space::next_proposal_id()
    }

    #[view]
    fn voting_delay() -> u64 {
        Space::voting_delay()
    }

    #[view]
    fn authenticators(account: ContractAddress) -> bool {
        Space::authenticators(account)
    }

    #[view]
    fn voting_strategies(index: u8) -> Strategy {
        Space::voting_strategies(index)
    }

    #[view]
    fn active_voting_strategies() -> u256 {
        Space::active_voting_strategies()
    }

    #[view]
    fn next_voting_strategy_index() -> u8 {
        Space::next_voting_strategy_index()
    }

    #[view]
    fn proposal_validation_strategy() -> Strategy {
        Space::proposal_validation_strategy()
    }

    #[view]
    fn proposals(proposal_id: u256) -> Proposal {
        Space::proposals(proposal_id)
    }

    #[external]
    fn set_max_voting_duration(max_voting_duration: u64) {
        Space::set_max_voting_duration(max_voting_duration);
    }

    #[external]
    fn set_min_voting_duration(min_voting_duration: u64) {
        Space::set_min_voting_duration(min_voting_duration);
    }

    #[external]
    fn set_voting_delay(voting_delay: u64) {
        Space::set_voting_delay(voting_delay);
    }

    #[external]
    fn set_proposal_validation_strategy(proposal_validation_strategy: Strategy) {
        Space::set_proposal_validation_strategy(proposal_validation_strategy);
    }

    #[external]
    fn add_voting_strategies(voting_strategies: Array<Strategy>) {
        Space::add_voting_strategies(voting_strategies);
    }

    #[external]
    fn remove_voting_strategies(voting_strategy_indices: Array<u8>) {
        Space::remove_voting_strategies(voting_strategy_indices);
    }

    #[external]
    fn add_authenticators(authenticators: Array<ContractAddress>) {
        Space::add_authenticators(authenticators);
    }

    #[external]
    fn remove_authenticators(authenticators: Array<ContractAddress>) {
        Space::remove_authenticators(authenticators);
    }

    #[external]
    fn transfer_ownership(new_owner: ContractAddress) {
        Space::transfer_ownership(new_owner);
    }

    #[external]
    fn renounce_ownership() {
        Space::renounce_ownership();
    }

    /// 
    /// Internals
    ///

    fn assert_only_authenticator() {
        let caller: ContractAddress = info::get_caller_address();
        assert(_authenticators::read(caller), 'Caller is not an authenticator');
    }

    fn assert_proposal_exists(proposal: @Proposal) {
        assert(!(*proposal.start_timestamp).is_zero(), 'Proposal does not exist');
    }

    fn _get_cumulative_power(
        voter: ContractAddress,
        timestamp: u64,
        user_strategies: Array<IndexedStrategy>,
        allowed_strategies: u256
    ) {}

    fn _set_max_voting_duration(_max_voting_duration: u64) {
        _max_voting_duration::write(_max_voting_duration);
    }

    fn _set_min_voting_duration(_min_voting_duration: u64) {
        _min_voting_duration::write(_min_voting_duration);
    }

    fn _set_voting_delay(_voting_delay: u64) {
        _voting_delay::write(_voting_delay);
    }

    fn _set_proposal_validation_strategy(_proposal_validation_strategy: Strategy) {
        _proposal_validation_strategy::write(_proposal_validation_strategy);
    }

    fn _add_voting_strategies(_voting_strategies: Array<Strategy>) {
        let mut cachedActiveVotingStrategies = _active_voting_strategies::read();
        let mut cachedNextVotingStrategyIndex = _next_voting_strategy_index::read();
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
            _voting_strategies::write(cachedNextVotingStrategyIndex, strategy);
            cachedNextVotingStrategyIndex += 1_u8;
            i += 1;
        };
        _active_voting_strategies::write(cachedActiveVotingStrategies);
        _next_voting_strategy_index::write(cachedNextVotingStrategyIndex);
    }
    // TODO: need to impl set_bit to false first
    // fn _remove_voting_strategies(_voting_strategies: Array<Strategy>) {
    //     let index = next_voting_strategy_index::read();
    //     voting_strategies::write(index, _voting_strategy);
    //     next_voting_strategy_index::write(index + 1_u8);
    // }

    fn _add_authenticators(_authenticators: Array<ContractAddress>) {
        let mut _authenticators_span = _authenticators.span();
        let mut i = 0_usize;
        loop {
            if i >= _authenticators.len() {
                break ();
            }
            _authenticators::write(*_authenticators_span.pop_front().unwrap(), true);
            i += 1;
        }
    }

    fn _remove_authenticators(_authenticators: Array<ContractAddress>) {
        let mut _authenticators_span = _authenticators.span();
        let mut i = 0_usize;
        loop {
            if i >= _authenticators.len() {
                break ();
            }
            _authenticators::write(*_authenticators_span.pop_front().unwrap(), false);
            i += 1;
        }
    }
}

