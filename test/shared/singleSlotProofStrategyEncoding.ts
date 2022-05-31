import { assert } from './helpers';

// single slot proof strategy parameter array encoding (Inclusive -> Exclusive):

// Start Index      End Index                             Name                Description
// 0             -> 4                                   - slot              - Key of the storage slot containing the balance that will be verified
// 4             -> 5                                   - num_nodes         - bigint of nodes in proof
// 5             -> 5+num_nodes                         - proof_sizes_bytes - Array of the sizes in bytes of each node proof
// 5+num_nodes   -> 5+2*num_nodes                       - proof_sizes_words - Array of the bigints of words in each node proof
// 5+2*num_nodes -> 5+2*num_nodes+sum(proof_size_words) - proofs_concat     - Array of the node proofs

export function encodeParams(
  slot: bigint[],
  proof_sizes_bytes: bigint[],
  proof_sizes_words: bigint[],
  proofs_concat: bigint[]
): bigint[] {
  assert(proof_sizes_bytes.length == proof_sizes_words.length, 'Invalid parameters');
  const num_nodes = BigInt(proof_sizes_bytes.length);
  return slot.concat([num_nodes], proof_sizes_bytes, proof_sizes_words, proofs_concat);
}

export function decodeParams(params: bigint[]): [bigint[], bigint[], bigint[], bigint[]] {
  assert(params.length >= 5, 'Invalid parameter array');
  const slot: bigint[] = [params[0], params[1], params[2], params[3]];
  const num_nodes = Number(params[4]);
  const proof_sizes_bytes = params.slice(5, 5 + num_nodes);
  const proof_sizes_words = params.slice(5 + num_nodes, 5 + 2 * num_nodes);
  const proofs_concat = params.slice(5 + 2 * num_nodes);
  const total = proof_sizes_words.reduce(function (x, y) {
    return x + y;
  }, BigInt(0));
  assert(total == BigInt(proofs_concat.length), 'Invalid parameter array');
  return [slot, proof_sizes_bytes, proof_sizes_words, proofs_concat];
}
