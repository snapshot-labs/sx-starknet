use starknet::EthAddress;

#[starknet::interface]
pub trait ISatellite<TContractState> {
    /// Returns value of a given storage slot of a given account, at a given block number on a given
    /// chain id.
    /// Reverts with "STORAGE_PROOF_SLOT_NOT_SAVED" if the slot is not saved.
    fn storageSlot(
        self: @TContractState,
        chain_id: u256,
        block_number: u256,
        account: EthAddress,
        slot_index: u256,
    ) -> u256;

    /// Returns block number with a biggest timestamp that is less than or equal to the given
    /// timestamp.
    /// In other words, it answers what was the latest block at a given timestamp (including block
    /// with equal timestamp).
    /// Reverts with "STORAGE_PROOF_TIMESTAMP_NOT_SAVED" if the timestamp is not saved.
    fn timestamp(self: @TContractState, chain_id: u256, timestamp: u256) -> u256;
}
