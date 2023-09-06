/// Option trait that execution strategies can decide to implement.
#[starknet::interface]
trait IQuorum<TContractState> {
    /// Returns the `quorum` value of an execution strategy.
    fn quorum(self: @TContractState) -> u256;
}
