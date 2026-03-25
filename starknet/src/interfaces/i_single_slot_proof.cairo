/// Optional trait that execution strategies can decide to implement.
#[starknet::interface]
trait ISingleSlotProof<TContractState> {
    /// View function implementing a call to the Satellite contract to get the L1 block number with a biggest timestamp that is less than or equal to the given timestamp.
    /// In other words, it answers what was the latest block at a given timestamp (including block with equal timestamp).
    /// Reverts if the timestamp is not saved.
    ///
    /// # Arguments
    ///
    /// * `timestamp` - The timestamp to query.
    /// 
    /// # Returns
    ///
    /// * `u256` - The L1 block number corresponding to the given timestamp.
    fn get_block_by_timestamp(self: @TContractState, timestamp: u32) -> u256;
}
