use array::ArrayTrait;
use starknet::class_hash::Felt252TryIntoClassHash;
use starknet::ContractAddress;
use starknet::syscalls::deploy_syscall;
use starknet::testing::set_caller_address;
use starknet::contract_address_const;
use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};
use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
use sx::utils::types::Strategy;
use traits::{Into, TryInto};
use core::result::ResultTrait;
use option::OptionTrait;
use integer::u256_from_felt252;
use clone::Clone;
use debug::PrintTrait;
use serde::ArraySerde;
use serde::Serde;

fn setup() -> ContractAddress {
    let owner = contract_address_const::<1>();
    let max_voting_duration = 2_u64;
    let min_voting_duration = 1_u64;
    let voting_delay = 1_u64;
    let voting_strategies = ArrayTrait::<Strategy>::new();
    let authenticators = ArrayTrait::<ContractAddress>::new();
    // Set account as default caller
    set_caller_address(owner);

    // Deploy Vanilla Proposal Validation Strategy
    let mut constructor_calldata = array::ArrayTrait::<felt252>::new();
    let (vanilla_address, _) = deploy_syscall(
        VanillaProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
        6,
        constructor_calldata.span(),
        true
    ).unwrap();

    let proposal_validation_strategy = Strategy {
        address: vanilla_address, params: ArrayTrait::<u8>::new()
    };

    // Deploy Space 
    let mut constructor_calldata2 = array::ArrayTrait::<felt252>::new();
    constructor_calldata2.append(owner.into());
    constructor_calldata2.append(max_voting_duration.into());
    constructor_calldata2.append(min_voting_duration.into());
    constructor_calldata2.append(voting_delay.into());
    proposal_validation_strategy.serialize(ref constructor_calldata2);
    voting_strategies.serialize(ref constructor_calldata2);
    authenticators.serialize(ref constructor_calldata2);
    // constructor_calldata2.print();

    let (space_address, _) = deploy_syscall(
        Space::TEST_CLASS_HASH.try_into().unwrap(), 6, constructor_calldata2.span(), true
    ).unwrap();

    space_address
}

#[test]
#[available_gas(1000000)]
fn test_constructor() {
    let owner = contract_address_const::<1>();
    let max_voting_duration = 2_u64;
    let min_voting_duration = 1_u64;
    let voting_delay = 1_u64;
    let proposal_validation_strategy = Strategy {
        address: contract_address_const::<1>(), params: ArrayTrait::<u8>::new()
    };
    let voting_strategies = ArrayTrait::<Strategy>::new();
    let authenticators = ArrayTrait::<ContractAddress>::new();

    // Set account as default caller
    set_caller_address(owner);

    Space::constructor(
        owner,
        max_voting_duration,
        min_voting_duration,
        voting_delay,
        proposal_validation_strategy.clone(),
        voting_strategies.clone(),
        authenticators.clone()
    );

    assert(Space::owner() == owner, 'owner should be set');
    assert(Space::max_voting_duration() == max_voting_duration, 'max');
    assert(Space::min_voting_duration() == min_voting_duration, 'min');
    assert(Space::voting_delay() == voting_delay, 'voting_delay');
// TODO: impl PartialEq for Strategy
// assert(space::proposal_validation_strategy() == proposal_validation_strategy, 'proposal_validation_strategy');

}

#[test]
#[available_gas(100000000)]
fn test_propose() {
    let space_address = setup();
    let space = ISpaceDispatcher { contract_address: space_address };
    assert(
        space.next_proposal_id() == u256 { low: 1_u128, high: 0_u128 },
        'next_proposal_id should be 1'
    );

    // TODO: impl vanilla execution strategy and use here
    let vanilla_execution_strategy = Strategy {
        address: contract_address_const::<1>(), params: ArrayTrait::<u8>::new()
    };
    let vanilla_proposal_validation_strategy_params = ArrayTrait::<u8>::new();
    space.propose(
        contract_address_const::<5678>(),
        vanilla_execution_strategy,
        vanilla_proposal_validation_strategy_params
    );
    assert(
        space.next_proposal_id() == u256 { low: 2_u128, high: 0_u128 },
        'next_proposal_id should be 2'
    );

    let proposal = space.proposals(u256 { low: 1_u128, high: 0_u128 });
// TODO: impl PartialEq for Proposal and check here
}

#[test]
#[available_gas(100000000)]
fn test_propose_failed_validation() {
    let space_address = setup();
    let space = ISpaceDispatcher { contract_address: space_address };
    assert(
        space.next_proposal_id() == u256 { low: 1_u128, high: 0_u128 },
        'next_proposal_id should be 1'
    );

    // TODO: impl vanilla execution strategy and use here
    let vanilla_execution_strategy = Strategy {
        address: contract_address_const::<1>(), params: ArrayTrait::<u8>::new()
    };
    let vanilla_proposal_validation_strategy_params = ArrayTrait::<u8>::new();
    space.propose(
        contract_address_const::<5678>(),
        vanilla_execution_strategy,
        vanilla_proposal_validation_strategy_params
    );
    assert(
        space.next_proposal_id() == u256 { low: 2_u128, high: 0_u128 },
        'next_proposal_id should be 2'
    );

    let proposal = space.proposals(u256 { low: 1_u128, high: 0_u128 });
// TODO: impl PartialEq for Proposal and check here
}

