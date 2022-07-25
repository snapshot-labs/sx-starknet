%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy, get_caller_address

@storage_var
func salt() -> (value : felt):
end

@storage_var
func space_class_hash_store() -> (value : felt):
end

@event
func space_deployed(
    deployer_address : felt,
    space_address : felt,
    voting_delay : felt,
    min_voting_duration : felt,
    max_voting_duration : felt,
    proposal_threshold : Uint256,
    controller : felt,
    quorum : Uint256,
    voting_strategies_len : felt,
    voting_strategies : felt*,
    authenticators_len : felt,
    authenticators : felt*,
    executors_len : felt,
    executors : felt*,
):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    space_class_hash : felt
):
    space_class_hash_store.write(space_class_hash)
    return ()
end

@external
func deploy_space{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr : felt}(
    public_key : felt,
    voting_delay : felt,
    min_voting_duration : felt,
    max_voting_duration : felt,
    proposal_threshold : Uint256,
    controller : felt,
    quorum : Uint256,
    voting_strategy_params_flat_len : felt,
    voting_strategy_params_flat : felt*,
    voting_strategies_len : felt,
    voting_strategies : felt*,
    authenticators_len : felt,
    authenticators : felt*,
    executors_len : felt,
    executors : felt*,
):
    alloc_locals
    let (calldata : felt*) = alloc()
    assert calldata[0] = public_key
    assert calldata[1] = voting_delay
    assert calldata[2] = min_voting_duration
    assert calldata[3] = max_voting_duration
    assert calldata[4] = proposal_threshold.low
    assert calldata[5] = proposal_threshold.high
    assert calldata[6] = controller
    assert calldata[7] = quorum.low
    assert calldata[8] = quorum.high
    assert calldata[9] = voting_strategy_params_flat_len
    memcpy(calldata + 10, voting_strategy_params_flat, voting_strategy_params_flat_len)
    assert calldata[10 + voting_strategy_params_flat_len] = voting_strategies_len
    memcpy(
        calldata + 11 + voting_strategy_params_flat_len, voting_strategies, voting_strategies_len
    )
    assert calldata[11 + voting_strategies_len + voting_strategy_params_flat_len] = authenticators_len
    memcpy(
        calldata + 12 + voting_strategies_len + voting_strategy_params_flat_len,
        authenticators,
        authenticators_len,
    )
    assert calldata[12 + voting_strategies_len + voting_strategy_params_flat_len + authenticators_len] = executors_len
    memcpy(
        calldata + 13 + voting_strategies_len + voting_strategy_params_flat_len + authenticators_len,
        executors,
        executors_len,
    )
    let (deployer_address) = get_caller_address()
    let calldata_len = 13 + voting_strategies_len + voting_strategy_params_flat_len + authenticators_len + executors_len
    let (current_salt) = salt.read()
    let (space_class_hash) = space_class_hash_store.read()
    let (space_address) = deploy(
        class_hash=space_class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=calldata_len,
        constructor_calldata=calldata,
        deploy_from_zero=0,
    )
    salt.write(value=current_salt + 1)

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
        authenticators_len,
        authenticators,
        executors_len,
        executors,
    )
    return ()
end
