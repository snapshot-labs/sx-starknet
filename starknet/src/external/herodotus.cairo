type Peaks = Span<felt252>;

type Proof = Span<felt252>;

type Words64 = Span<u64>;

#[derive(Drop, Serde)]
struct ProofElement {
    index: usize,
    value: u256,
    proof: Proof,
}

#[derive(Drop, Serde)]
struct BinarySearchTree {
    mapper_id: usize,
    last_pos: usize, // last_pos in mapper's MMR
    peaks: Peaks,
    proofs: Span<ProofElement>, // Midpoint elements inclusion proofs
    left_neighbor: Option<ProofElement>, // Optional left neighbor inclusion proof
}

#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    // Retrieves the timestamp of the L1 block closest to the given timestamp.
    fn get_closest_l1_block_number(
        self: @TContractState, tree: BinarySearchTree, timestamp: u256
    ) -> Result<Option<u256>, felt252>;

    // Getter for the last timestamp of a given mapper.
    fn get_last_mapper_timestamp(self: @TContractState, mapper_id: usize) -> u256;
}

#[starknet::interface]
trait IEVMFactsRegistry<TContractState> {
    fn get_storage(
        self: @TContractState,
        block: u256,
        account: felt252,
        slot: u256,
        slot_len: usize,
        mpt_proof: Span<Words64>
    ) -> u256;
}
