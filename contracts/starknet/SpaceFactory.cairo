// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy, get_caller_address

//
// @title Snapshot X Space Factory
// @author SnapshotLabs
// @notice Contract to deploy space contracts in a trackable way
// @notice The space contract needs to be declared on StarkNet first, which will return the clash hash that is passed to the constructor of this contract
//

// @dev Stores a counter to ensure a unique salt for each deployment
@storage_var
func SpaceFactory_salt() -> (value: felt) {
}

// @dev Stores the clash hash for the space contract
@storage_var
func SpaceFactory_space_class_hash_store() -> (value: felt) {
}

@event
func space_deployed(
    deployer_address: felt,
    space_address: felt,
    voting_delay: felt,
    min_voting_duration: felt,
    max_voting_duration: felt,
    proposal_threshold: Uint256,
    controller: felt,
    quorum: Uint256,
    voting_strategies_len: felt,
    voting_strategies: felt*,
    voting_strategy_params_flat_len: felt,
    voting_strategy_params_flat: felt*,
    authenticators_len: felt,
    authenticators: felt*,
    execution_strategies_len: felt,
    execution_strategies: felt*,
    metadata_uri_len: felt,
    metadata_uri: felt*,
) {
}

// @dev Constructor
// @param space_class_hash Class hash of the space contract
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    space_class_hash: felt
) {
    SpaceFactory_space_class_hash_store.write(space_class_hash);
    return ();
}

// @dev Deploys a space contract instance
// @param public_key The public key that can execute transactions via this account - Can set to zero if this functionality is unwanted
// @param voting_delay The delay between when a proposal is created, and when the voting starts
// @param min_voting_duration The minimum duration of the voting period
// @param max_voting_duration The maximum duration of the voting period
// @param proposal_threshold The minimum amount of voting power needed to be able to create a new proposal in the space
// @param controller The address of the controller account for the space
// @param quorum The minimum total voting power required for a proposal to pass
// @param voting_strategies Array of whitelisted voting strategy contract addresses
// @param voting_strategy_params_flat Flattened 2D array of voting strategy parameters
// @param authenticators Array of whitelisted authenticator contract addresses
// @param execution_strategies Array of whitelisted execution strategy contract addresses
// @param metadata_uri The metadata URI for the space
@external
func deploySpace{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    public_key: felt,
    voting_delay: felt,
    min_voting_duration: felt,
    max_voting_duration: felt,
    proposal_threshold: Uint256,
    controller: felt,
    quorum: Uint256,
    voting_strategies_len: felt,
    voting_strategies: felt*,
    voting_strategy_params_flat_len: felt,
    voting_strategy_params_flat: felt*,
    authenticators_len: felt,
    authenticators: felt*,
    execution_strategies_len: felt,
    execution_strategies: felt*,
    metadata_uri_len: felt,
    metadata_uri: felt*,
) {
    alloc_locals;
    let (calldata: felt*) = alloc();
    assert calldata[0] = public_key;
    assert calldata[1] = voting_delay;
    assert calldata[2] = min_voting_duration;
    assert calldata[3] = max_voting_duration;
    assert calldata[4] = proposal_threshold.low;
    assert calldata[5] = proposal_threshold.high;
    assert calldata[6] = controller;
    assert calldata[7] = quorum.low;
    assert calldata[8] = quorum.high;
    assert calldata[9] = voting_strategies_len;
    memcpy(calldata + 10, voting_strategies, voting_strategies_len);
    assert calldata[10 + voting_strategies_len] = voting_strategy_params_flat_len;
    memcpy(
        calldata + 11 + voting_strategies_len,
        voting_strategy_params_flat,
        voting_strategy_params_flat_len,
    );
    assert calldata[11 + voting_strategies_len + voting_strategy_params_flat_len] = authenticators_len;
    memcpy(
        calldata + 12 + voting_strategies_len + voting_strategy_params_flat_len,
        authenticators,
        authenticators_len,
    );
    assert calldata[12 + voting_strategies_len + voting_strategy_params_flat_len + authenticators_len] = execution_strategies_len;
    memcpy(
        calldata + 13 + voting_strategies_len + voting_strategy_params_flat_len + authenticators_len,
        execution_strategies,
        execution_strategies_len,
    );
    // NOTE: The metadata URI is not stored in the contract state (its just emitted as an event). Therefore it does not need to be passed as a parameter in the space deployment
    let (deployer_address) = get_caller_address();
    let calldata_len = 13 + voting_strategies_len + voting_strategy_params_flat_len + authenticators_len + execution_strategies_len;
    let (current_salt) = SpaceFactory_salt.read();
    let (space_class_hash) = SpaceFactory_space_class_hash_store.read();
    let (space_address) = deploy(
        class_hash=space_class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=calldata_len,
        constructor_calldata=calldata,
        deploy_from_zero=0,
    );
    SpaceFactory_salt.write(value=current_salt + 1);

    space_deployed.emit(
        deployer_address,
        space_address,
        voting_delay,
        min_voting_duration,
        max_voting_duration,
        proposal_threshold,
        controller,
        quorum,
        voting_strategies_len,
        voting_strategies,
        voting_strategy_params_flat_len,
        voting_strategy_params_flat,
        authenticators_len,
        authenticators,
        execution_strategies_len,
        execution_strategies,
        metadata_uri_len,
        metadata_uri,
    );
    return ();
}
