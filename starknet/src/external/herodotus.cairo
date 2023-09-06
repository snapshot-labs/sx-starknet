#[starknet::interface]
trait ITimestampRemappers<TContractState> {
    fn get_closest_l1_block_number(
        self: @TContractState, tree: BinarySearchTree, timestamp: u256
    ) -> Option<u256>;
}

#[starknet::interface]
trait IEVMFactsRegistry<TContractState> {
    fn get_slot_value(self: @TContractState, account: felt252, block: u256, slot: u256) -> u256;
}

type Peaks = Span<felt252>;

type Proof = Span<felt252>;

#[derive(Drop, Copy, Serde)]
struct ProofElement {
    index: usize,
    value: u256,
    peaks: Peaks,
    proof: Proof,
    last_pos: usize,
}

#[derive(Drop, Copy, Serde)]
struct BinarySearchTree {
    mapper_id: usize,
    mmr_id: usize,
    proofs: Span<ProofElement>,
    left_neighbor: Option<ProofElement>,
}
