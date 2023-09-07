type Peaks = Span<felt252>;

type Proof = Span<felt252>;

type Words64 = Span<u64>;

#[derive(Drop, Serde)]
struct ProofElement {
    index: usize,
    value: u256,
    peaks: Peaks,
    proof: Proof,
    last_pos: usize,
}

#[derive(Drop, Serde)]
struct BinarySearchTree {
    mapper_id: usize,
    last_pos: usize,
    proofs: Span<ProofElement>,
    left_neighbor: Option<ProofElement>,
}

#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    fn get_closest_l1_block_number(
        self: @TContractState, tree: BinarySearchTree, timestamp: u256
    ) -> Result<Option<u256>, felt252>;
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
