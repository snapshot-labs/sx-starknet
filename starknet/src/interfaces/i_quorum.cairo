#[starknet::interface]
trait IQuorum<TContractState> {
    fn quorum(self: @TContractState) -> u256;
}
