#[starknet::interface]
trait IQuorum<TContractState> {
    /// Returns the number `quorum` value of an execution strategy.
    fn quorum(self: @TContractState) -> u256;
}
