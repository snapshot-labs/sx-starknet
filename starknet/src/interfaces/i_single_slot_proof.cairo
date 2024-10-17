use sx::external::herodotus::BinarySearchTree;

/// Optional trait that execution strategies can decide to implement.
#[starknet::interface]
trait ISingleSlotProof<TContractState> {
    /// Queries the Timestamp Remapper contract for the closest L1 block number that occurred before
    /// the given timestamp and then caches the result. If the queried timestamp is less than the earliest
    /// timestamp or larger than the latest timestamp in the mapper then the transaction will revert.
    /// This function should be used to cache a remapped timestamp before it's used when calling the 
    /// `get_storage_slot` function with the same timestamp.
    ///
    /// # Arguments
    ///
    /// * `timestamp` - The timestamp at which to query.
    /// * `tree` - The tree proof required to query the remapper.
    fn cache_timestamp(ref self: TContractState, timestamp: u32, tree: BinarySearchTree);

    /// View function exposing the cached remapped timestamps. Reverts if the timestamp is not cached.
    ///
    /// # Arguments
    ///
    /// * `timestamp` - The timestamp to query.
    /// 
    /// # Returns
    ///
    /// * `u256` - The cached L1 block number corresponding to the timestamp.
    fn cached_timestamps(self: @TContractState, timestamp: u32) -> u256;
}
