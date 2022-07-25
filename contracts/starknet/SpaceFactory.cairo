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
    _voting_delay : felt,
    _min_voting_duration : felt,
    _max_voting_duration : felt,
    _proposal_threshold : Uint256,
    _controller : felt,
    _quorum : Uint256,
    _voting_strategies_len : felt,
    _voting_strategies : felt*,
    _authenticators_len : felt,
    _authenticators : felt*,
    _executors_len : felt,
    _executors : felt*,
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
    _voting_delay : felt,
    _min_voting_duration : felt,
    _max_voting_duration : felt,
    _proposal_threshold : Uint256,
    _controller : felt,
    _quorum : Uint256,
    _voting_strategy_params_flat_len : felt,
    _voting_strategy_params_flat : felt*,
    _voting_strategies_len : felt,
    _voting_strategies : felt*,
    _authenticators_len : felt,
    _authenticators : felt*,
    _executors_len : felt,
    _executors : felt*,
):
    alloc_locals
    let (calldata : felt*) = alloc()
    assert calldata[0] = _voting_delay
    assert calldata[1] = _min_voting_duration
    assert calldata[2] = _max_voting_duration
    assert calldata[3] = _proposal_threshold.low
    assert calldata[4] = _proposal_threshold.high
    assert calldata[5] = _controller
    assert calldata[6] = _quorum.low
    assert calldata[7] = _quorum.high
    assert calldata[8] = _voting_strategy_params_flat_len
    memcpy(calldata + 9, _voting_strategy_params_flat, _voting_strategy_params_flat_len)
    assert calldata[9 + _voting_strategy_params_flat_len] = _voting_strategies_len
    memcpy(
        calldata + 10 + _voting_strategy_params_flat_len, _voting_strategies, _voting_strategies_len
    )
    assert calldata[10 + _voting_strategies_len + _voting_strategy_params_flat_len] = _authenticators_len
    memcpy(
        calldata + 11 + _voting_strategies_len + _voting_strategy_params_flat_len,
        _authenticators,
        _authenticators_len,
    )
    assert calldata[11 + _voting_strategies_len + _voting_strategy_params_flat_len + _authenticators_len] = _executors_len
    memcpy(
        calldata + 12 + _voting_strategies_len + _voting_strategy_params_flat_len + _authenticators_len,
        _executors,
        _executors_len,
    )
    let (deployer_address) = get_caller_address()
    let calldata_len = 12 + _voting_strategies_len + _voting_strategy_params_flat_len + _authenticators_len + _executors_len
    let (current_salt) = salt.read()
    let (space_class_hash) = space_class_hash_store.read()
    let (space_address) = deploy(
        class_hash=space_class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=calldata_len,
        constructor_calldata=calldata,
        deploy_from_zero=0
    )
    salt.write(value=current_salt + 1)

    space_deployed.emit(
        deployer_address,
        1,
        _voting_delay,
        _min_voting_duration,
        _max_voting_duration,
        _proposal_threshold,
        _controller,
        _quorum,
        _voting_strategies_len,
        _voting_strategies,
        _authenticators_len,
        _authenticators,
        _executors_len,
        _executors,
    )
    return ()
end
