use array::ArrayTrait;
use starknet::{
    class_hash::Felt252TryIntoClassHash, ContractAddress, syscalls::deploy_syscall, testing,
    contract_address_const, info
};
use traits::{Into, TryInto};
use result::ResultTrait;
use option::OptionTrait;
use integer::u256_from_felt252;
use clone::Clone;
use debug::PrintTrait;
use serde::{Serde};

use sx::space::space::{Space, ISpaceDispatcher, ISpaceDispatcherTrait};
use sx::authenticators::vanilla::{
    VanillaAuthenticator, IVanillaAuthenticatorDispatcher, IVanillaAuthenticatorDispatcherTrait
};
use sx::execution_strategies::vanilla::VanillaExecutionStrategy;
use sx::voting_strategies::vanilla::VanillaVotingStrategy;
use sx::proposal_validation_strategies::vanilla::VanillaProposalValidationStrategy;
use sx::tests::mocks::proposal_validation_always_fail::AlwaysFailProposalValidationStrategy;
use sx::utils::types::{Strategy, IndexedStrategy, Choice, FinalizationStatus, Proposal};
use sx::utils::constants::{PROPOSE_SELECTOR, VOTE_SELECTOR, UPDATE_PROPOSAL_SELECTOR};

use Space::Space as SpaceImpl;
// fn setup(
//     deployer: ContractAddress
// ) -> (ContractAddress, ContractAddress, Strategy, ContractAddress) {
//     testing::set_caller_address(deployer);
//     testing::set_contract_address(deployer);

//     // Space Settings
//     let owner = contract_address_const::<0x123456789>();
//     let max_voting_duration = 2_u64;
//     let min_voting_duration = 1_u64;
//     let voting_delay = 1_u64;
//     let quorum = u256_from_felt252(1);

//     // Deploy Vanilla Authenticator 
//     let (vanilla_authenticator_address, _) = deploy_syscall(
//         VanillaAuthenticator::TEST_CLASS_HASH.try_into().unwrap(),
//         0,
//         array::ArrayTrait::<felt252>::new().span(),
//         false
//     )
//         .unwrap();
//     let mut authenticators = ArrayTrait::<ContractAddress>::new();
//     authenticators.append(vanilla_authenticator_address);

//     // Deploy Vanilla Proposal Validation Strategy
//     let (vanilla_proposal_validation_address, _) = deploy_syscall(
//         VanillaProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
//         0,
//         array::ArrayTrait::<felt252>::new().span(),
//         false
//     )
//         .unwrap();
//     let vanilla_proposal_validation_strategy = Strategy {
//         address: vanilla_proposal_validation_address, params: ArrayTrait::<felt252>::new()
//     };

//     // Deploy Vanilla Voting Strategy 
//     let (vanilla_voting_strategy_address, _) = deploy_syscall(
//         VanillaVotingStrategy::TEST_CLASS_HASH.try_into().unwrap(),
//         0,
//         array::ArrayTrait::<felt252>::new().span(),
//         false
//     )
//         .unwrap();
//     let mut voting_strategies = ArrayTrait::<Strategy>::new();
//     voting_strategies
//         .append(
//             Strategy {
//                 address: vanilla_voting_strategy_address, params: ArrayTrait::<felt252>::new()
//             }
//         );

//     // Deploy Vanilla Execution Strategy 
//     let mut constructor_calldata = ArrayTrait::<felt252>::new();
//     quorum.serialize(ref constructor_calldata);
//     let (vanilla_execution_strategy_address, _) = deploy_syscall(
//         VanillaExecutionStrategy::TEST_CLASS_HASH.try_into().unwrap(),
//         0,
//         constructor_calldata.span(),
//         false
//     )
//         .unwrap();
//     let vanilla_execution_strategy = Strategy {
//         address: vanilla_execution_strategy_address, params: ArrayTrait::<felt252>::new()
//     };

//     // Deploy Space 
//     let mut constructor_calldata = array::ArrayTrait::<felt252>::new();
//     constructor_calldata.append(owner.into());
//     constructor_calldata.append(max_voting_duration.into());
//     constructor_calldata.append(min_voting_duration.into());
//     constructor_calldata.append(voting_delay.into());
//     vanilla_proposal_validation_strategy.serialize(ref constructor_calldata);
//     voting_strategies.serialize(ref constructor_calldata);
//     authenticators.serialize(ref constructor_calldata);

//     let (space_address, _) = deploy_syscall(
//         Space::TEST_CLASS_HASH.try_into().unwrap(), 0, constructor_calldata.span(), false
//     )
//         .unwrap();

//     (space_address, vanilla_authenticator_address, vanilla_execution_strategy, owner)
// }

// // #[test]
// // #[available_gas(1000000)]
// // fn test_constructor() {
// //     let owner = contract_address_const::<1>();
// //     let max_voting_duration = 2_u64;
// //     let min_voting_duration = 1_u64;
// //     let voting_delay = 1_u64;
// //     let proposal_validation_strategy = Strategy {
// //         address: contract_address_const::<1>(), params: ArrayTrait::<felt252>::new()
// //     };
// //     let voting_strategies = ArrayTrait::<Strategy>::new();
// //     let authenticators = ArrayTrait::<ContractAddress>::new();

// //     // Set account as default caller
// //     testing::set_caller_address(owner);

// //     Space::constructor(
// //         owner,
// //         max_voting_duration,
// //         min_voting_duration,
// //         voting_delay,
// //         proposal_validation_strategy.clone(),
// //         voting_strategies.clone(),
// //         authenticators.clone()
// //     );

// //     assert(SpaceImpl::owner() == owner, 'owner should be set');
// //     assert(SpaceImpl::max_voting_duration() == max_voting_duration, 'max');
// //     assert(SpaceImpl::min_voting_duration() == min_voting_duration, 'min');
// //     assert(SpaceImpl::voting_delay() == voting_delay, 'voting_delay');
// // // TODO: impl PartialEq for Strategy
// // // assert(space::proposal_validation_strategy() == proposal_validation_strategy, 'proposal_validation_strategy');

// // }

// #[test]
// #[available_gas(10000000000)]
// fn test__propose_update_vote_execute() {
//     let relayer = contract_address_const::<0x1234>();
//     let (space_address, vanilla_authenticator_address, vanilla_execution_strategy, owner) = setup(
//         relayer
//     );
//     let space = ISpaceDispatcher { contract_address: space_address };
//     let authenticator = IVanillaAuthenticatorDispatcher {
//         contract_address: vanilla_authenticator_address
//     };
//     assert(
//         space.next_proposal_id() == u256 { low: 1_u128, high: 0_u128 },
//         'next_proposal_id should be 1'
//     );

//     let author = contract_address_const::<0x5678>();
//     let mut propose_calldata = array::ArrayTrait::<felt252>::new();
//     author.serialize(ref propose_calldata);
//     vanilla_execution_strategy.serialize(ref propose_calldata);
//     ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

//     // Create Proposal
//     authenticator.authenticate(space_address, PROPOSE_SELECTOR, propose_calldata);

//     assert(
//         space.next_proposal_id() == u256 { low: 2_u128, high: 0_u128 },
//         'next_proposal_id should be 2'
//     );

//     let proposal = space.proposals(u256_from_felt252(1));
//     let expected_proposal = Proposal {
//         snapshot_timestamp: info::get_block_timestamp(),
//         start_timestamp: info::get_block_timestamp() + 1_u64,
//         min_end_timestamp: info::get_block_timestamp() + 2_u64,
//         max_end_timestamp: info::get_block_timestamp() + 3_u64,
//         execution_payload_hash: poseidon::poseidon_hash_span(
//             vanilla_execution_strategy.clone().params.span()
//         ),
//         execution_strategy: vanilla_execution_strategy.address,
//         author: author,
//         finalization_status: FinalizationStatus::Pending(()),
//         active_voting_strategies: u256_from_felt252(1)
//     };
//     assert(proposal == expected_proposal, 'proposal state');

//     // Update Proposal
//     let mut update_calldata = array::ArrayTrait::<felt252>::new();
//     author.serialize(ref update_calldata);
//     let proposal_id = u256_from_felt252(1);
//     proposal_id.serialize(ref update_calldata);
//     // Keeping the same execution strategy contract but changing the payload
//     let mut new_payload = ArrayTrait::<felt252>::new();
//     new_payload.append(1);
//     let execution_strategy = Strategy {
//         address: vanilla_execution_strategy.address, params: new_payload
//     };
//     execution_strategy.serialize(ref update_calldata);

//     authenticator.authenticate(space_address, UPDATE_PROPOSAL_SELECTOR, update_calldata);

//     // Increasing block timestamp by 1 to pass voting delay
//     testing::set_block_timestamp(1_u64);

//     let mut vote_calldata = array::ArrayTrait::<felt252>::new();
//     vote_calldata.append(contract_address_const::<8765>().into());
//     let proposal_id = u256_from_felt252(1);
//     proposal_id.serialize(ref vote_calldata);
//     let choice = Choice::For(());
//     choice.serialize(ref vote_calldata);
//     let mut user_voting_strategies = ArrayTrait::<IndexedStrategy>::new();
//     user_voting_strategies
//         .append(IndexedStrategy { index: 0_u8, params: ArrayTrait::<felt252>::new() });
//     user_voting_strategies.serialize(ref vote_calldata);

//     // Vote on Proposal
//     authenticator.authenticate(space_address, VOTE_SELECTOR, vote_calldata);

//     testing::set_block_timestamp(2_u64);

//     // Execute Proposal
//     space.execute(u256_from_felt252(1), vanilla_execution_strategy.params);
// }

// #[test]
// #[available_gas(100000000)]
// #[should_panic(expected: ('Proposal is not valid', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
// fn test__propose_failed_validation() {
//     let relayer = contract_address_const::<0x1234>();
//     let (space_address, vanilla_authenticator_address, vanilla_execution_strategy, owner) = setup(
//         relayer
//     );
//     let space = ISpaceDispatcher { contract_address: space_address };
//     let authenticator = IVanillaAuthenticatorDispatcher {
//         contract_address: vanilla_authenticator_address
//     };
//     assert(
//         space.next_proposal_id() == u256 { low: 1_u128, high: 0_u128 },
//         'next_proposal_id should be 1'
//     );

//     // Replace proposal validation strategy with one that always fails
//     let (strategy_address, _) = deploy_syscall(
//         AlwaysFailProposalValidationStrategy::TEST_CLASS_HASH.try_into().unwrap(),
//         0,
//         array::ArrayTrait::<felt252>::new().span(),
//         false
//     )
//         .unwrap();
//     testing::set_caller_address(owner);
//     testing::set_contract_address(owner);
//     space
//         .set_proposal_validation_strategy(
//             Strategy { address: strategy_address, params: ArrayTrait::<felt252>::new() }
//         );

//     let mut propose_calldata = array::ArrayTrait::<felt252>::new();
//     propose_calldata.append(contract_address_const::<5678>().into());
//     vanilla_execution_strategy.serialize(ref propose_calldata);
//     ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

//     // Try to create Proposal
//     authenticator.authenticate(space_address, PROPOSE_SELECTOR, propose_calldata);
// }

// #[test]
// #[available_gas(10000000000)]
// #[should_panic(expected: ('Proposal has been finalized', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
// fn test__cancel() {
//     let relayer = contract_address_const::<0x1234>();
//     let (space_address, vanilla_authenticator_address, vanilla_execution_strategy, owner) = setup(
//         relayer
//     );
//     let space = ISpaceDispatcher { contract_address: space_address };
//     let authenticator = IVanillaAuthenticatorDispatcher {
//         contract_address: vanilla_authenticator_address
//     };

//     let author = contract_address_const::<0x5678>();
//     let mut propose_calldata = array::ArrayTrait::<felt252>::new();
//     author.serialize(ref propose_calldata);
//     vanilla_execution_strategy.serialize(ref propose_calldata);
//     ArrayTrait::<felt252>::new().serialize(ref propose_calldata);

//     // Create Proposal
//     authenticator.authenticate(space_address, PROPOSE_SELECTOR, propose_calldata);
//     let proposal_id = u256_from_felt252(1);

//     // Increasing block timestamp by 1 to pass voting delay
//     testing::set_block_timestamp(1_u64);
//     let proposal = space.proposals(proposal_id);
//     assert(proposal.finalization_status == FinalizationStatus::Pending(()), 'pending');

//     // Cancel Proposal
//     testing::set_caller_address(owner);
//     testing::set_contract_address(owner);
//     space.cancel_proposal(proposal_id);

//     let proposal = space.proposals(proposal_id);
//     assert(proposal.finalization_status == FinalizationStatus::Cancelled(()), 'cancelled');

//     // Try to cast vote on Cancelled Proposal
//     let mut vote_calldata = array::ArrayTrait::<felt252>::new();
//     vote_calldata.append(contract_address_const::<8765>().into());
//     proposal_id.serialize(ref vote_calldata);
//     let choice = Choice::For(());
//     choice.serialize(ref vote_calldata);
//     let mut user_voting_strategies = ArrayTrait::<IndexedStrategy>::new();
//     user_voting_strategies
//         .append(IndexedStrategy { index: 0_u8, params: ArrayTrait::<felt252>::new() });
//     user_voting_strategies.serialize(ref vote_calldata);
//     authenticator.authenticate(space_address, VOTE_SELECTOR, vote_calldata);
// }

