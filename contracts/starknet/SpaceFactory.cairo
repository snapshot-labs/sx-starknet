%lang starknet

from starkware.starknet.common.syscalls import deploy

@storage_var
func salt() -> (value : felt):
end

@storage_var
func space_class_hash() -> (value : felt):
end

@event
func space_deployed():
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _space_class_hash : felt
):
    space_class_hash.write(_space_class_hash)
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
    let (current_salt) = salt.read()
    let (space_class_hash) = space_class_hash.read()
    let (space_address) = deploy(
        class_hash=space_class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=1,
        constructor_calldata=cast(new (owner_address,), felt*),
    )
end
