use array::ArrayTrait;
use array::SpanTrait;
use starknet::account::Call;
use starknet::ContractAddress;

// Interfaces from OZ: https://github.com/OpenZeppelin/cairo-contracts/blob/cairo-2/src/account/interface.cairo
#[starknet::interface]
trait AccountABI<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @TState, class_hash: felt252) -> felt252;
    fn __validate_deploy__(
        self: @TState, class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252;
    fn set_public_key(ref self: TState, new_public_key: felt252);
    fn get_public_key(self: @TState) -> felt252;
    fn is_valid_signature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

// Entry points case-convention is enforced by the protocol
#[starknet::interface]
trait AccountCamelABI<TState> {
    fn __execute__(self: @TState, calls: Array<Call>) -> Array<Span<felt252>>;
    fn __validate__(self: @TState, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @TState, classHash: felt252) -> felt252;
    fn __validate_deploy__(
        self: @TState, classHash: felt252, contractAddressSalt: felt252, _publicKey: felt252
    ) -> felt252;
    fn setPublicKey(ref self: TState, newPublicKey: felt252);
    fn getPublicKey(self: @TState) -> felt252;
    fn isValidSignature(self: @TState, hash: felt252, signature: Array<felt252>) -> felt252;
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;
}
