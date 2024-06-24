type Peaks = Span<felt252>;

type Proof = Span<felt252>;

type Words64 = Span<u64>;

type MapperId = u256;

type MmrSize =
    u256; // From 'https://github.com/HerodotusDev/cairo-lib/blob/update-cairo/src/data_structures/mmr/mmr.cairo'


#[derive(Drop, Serde)]
struct ProofElement {
    index: MmrSize,
    value: u256,
    proof: Proof,
}

#[derive(Drop, Serde)]
struct BinarySearchTree {
    mapper_id: MapperId,
    last_pos: MmrSize, // last_pos in mapper's MMR
    peaks: Peaks,
    proofs: Span<ProofElement>, // Midpoint elements inclusion proofs
    left_neighbor: Option<ProofElement>, // Optional left neighbor inclusion proof
}

#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    // Retrieves the block number of the L1 closest timestamp to the given timestamp.
    fn get_closest_l1_block_number(
        self: @TContractState, tree: BinarySearchTree, timestamp: u256
    ) -> Result<Option<u256>, felt252>;

    // Getter for the last timestamp of a given mapper.
    fn get_last_mapper_timestamp(self: @TContractState, mapper_id: MapperId) -> u256;
}

#[starknet::interface]
trait IEVMFactsRegistry<TContractState> {
    fn get_storage(
        self: @TContractState, block: u256, account: felt252, slot: u256, mpt_proof: Span<Words64>
    ) -> u256;
}
