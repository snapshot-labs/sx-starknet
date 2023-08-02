use array::ArrayTrait;
use array::SpanTrait;
use starknet::account::Call;
use starknet::ContractAddress;

#[starknet::interface]
trait IAccount<TState> {
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
