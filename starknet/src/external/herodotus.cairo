use starknet::EthAddress;

type Words64 = Span<u64>;

#[derive(Drop, Serde)]
pub enum AccountField {
    NONCE,
    BALANCE,
    STORAGE_ROOT,
    CODE_HASH,
    APE_FLAGS,
    APE_FIXED,
    APE_SHARES,
    APE_DEBT,
    APE_DELEGATE,
}

impl AccountFieldIntoU32 of Into<AccountField, u32> {
    fn into(self: AccountField) -> u32 {
        match self {
            AccountField::NONCE => 0,
            AccountField::BALANCE => 1,
            AccountField::STORAGE_ROOT => 2,
            AccountField::CODE_HASH => 3,
            AccountField::APE_FLAGS => 4,
            AccountField::APE_FIXED => 5,
            AccountField::APE_SHARES => 6,
            AccountField::APE_DEBT => 7,
            AccountField::APE_DELEGATE => 8,
        }
    }
}

#[starknet::interface]
pub trait ISatellite<TContractState> {
    /// Returns account field (e.g. nonce, balance or storage root) of a given account, at a given
    /// block number on a given chain id.
    /// Reverts with "STORAGE_PROOF_ACCOUNT_FIELD_NOT_SAVED" if the field is not saved.
    fn accountField(
        self: @TContractState,
        chain_id: u256,
        block_number: u256,
        account: EthAddress,
        field: AccountField,
    ) -> u256;

    /// Verifies the storageSlotMptProof against account's storage root.
    /// Returns storage slot value.
    /// IMPORTANT: It DOES NOT check whether storage root is valid given the chain id, block number,
    /// account address and slot index.
    /// To verify storage root, use verifyOnlyAccount function.
    fn verifyOnlyStorage(
        self: @TContractState,
        slot: u256,
        storage_root: u256,
        storage_slot_mpt_proof: Span<Words64>,
    ) -> u256;

    /// Returns block number with a biggest timestamp that is less than or equal to the given
    /// timestamp.
    /// In other words, it answers what was the latest block at a given timestamp (including block
    /// with equal timestamp).
    /// Reverts with "STORAGE_PROOF_TIMESTAMP_NOT_SAVED" if the timestamp is not saved.
    fn timestamp(self: @TContractState, chain_id: u256, timestamp: u256) -> u256;
}
