// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0b (account/presets/Account.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_tx_info
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.account.library import Account, AccountCallArray
from contracts.starknet.lib.voting import Voting
from contracts.starknet.lib.general_address import Address

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    public_key: felt,
    voting_delay: felt,
    min_voting_duration: felt,
    max_voting_duration: felt,
    proposal_threshold: Uint256,
    controller: felt,
    quorum: Uint256,
    voting_strategy_params_flat_len: felt,
    voting_strategy_params_flat: felt*,
    voting_strategies_len: felt,
    voting_strategies: felt*,
    authenticators_len: felt,
    authenticators: felt*,
    executors_len: felt,
    executors: felt*,
) {
    Account.initializer(public_key);

    Voting.initializer(
        voting_delay,
        min_voting_duration,
        max_voting_duration,
        proposal_threshold,
        controller,
        quorum,
        voting_strategy_params_flat_len,
        voting_strategy_params_flat,
        voting_strategies_len,
        voting_strategies,
        authenticators_len,
        authenticators,
        executors_len,
        executors,
    );
    return ();
}

//
// Getters
//

@view
func getPublicKey{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    publicKey: felt
) {
    let (publicKey: felt) = Account.get_public_key();
    return (publicKey=publicKey);
}

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return Account.supports_interface(interfaceId);
}

//
// Setters
//

@external
func setPublicKey{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    newPublicKey: felt
) {
    Account.set_public_key(newPublicKey);
    return ();
}

//
// Business logic
//

@view
func isValidSignature{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(hash: felt, signature_len: felt, signature: felt*) -> (isValid: felt) {
    let (isValid: felt) = Account.is_valid_signature(hash, signature_len, signature);
    return (isValid=isValid);
}

@external
func __validate__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) {
    let (tx_info) = get_tx_info();
    Account.is_valid_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}

@external
func __validate_declare__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, ecdsa_ptr: SignatureBuiltin*, range_check_ptr
}(class_hash: felt) {
    let (tx_info) = get_tx_info();
    Account.is_valid_signature(tx_info.transaction_hash, tx_info.signature_len, tx_info.signature);
    return ();
}

@external
func __execute__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(call_array_len: felt, call_array: AccountCallArray*, calldata_len: felt, calldata: felt*) -> (
    response_len: felt, response: felt*
) {
    let (response_len, response) = Account.execute(
        call_array_len, call_array, calldata_len, calldata
    );
    return (response_len, response);
}

@external
func propose{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr: felt}(
    proposer_address: Address,
    metadata_uri_string_len: felt,
    metadata_uri_len: felt,
    metadata_uri: felt*,
    executor: felt,
    used_voting_strategies_len: felt,
    used_voting_strategies: felt*,
    user_voting_strategy_params_flat_len: felt,
    user_voting_strategy_params_flat: felt*,
    execution_params_len: felt,
    execution_params: felt*,
) -> () {
    alloc_locals;

    return ();
}
