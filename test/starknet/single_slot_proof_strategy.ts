import { expect } from 'chai';
import { block } from './data/blocks';
import { proofs } from './data/proofs';
import { SplitUint256 } from './shared/types';
import { ProofInputs } from './shared/parseRPCData';
import { encodeParams } from './shared/singleSlotProofStrategyEncoding';
import { singleSlotProofSetup } from '../starknet/shared/setup';

describe('Snapshot X Single Slot Strategy:', () => {
  it('The strategy should return the voting power', async () => {
    // Encode proof data to produce the inputs for the account and storage proofs.
    const proofInputs = ProofInputs.fromProofRPCData(block.number, proofs, encodeParams);

    // Deploy Fossil storage verifier instance and the voting strategy contract.
    const { account, singleSlotProofStrategy, fossil } = await singleSlotProofSetup();

    // Verify an account proof to obtain the storage root for the account at the specified block number trustlessly on-chain.
    await account.invoke(fossil.factsRegistry, 'prove_account', {
      options_set: proofInputs.accountOptions,
      block_number: proofInputs.blockNumber,
      account: {
        word_1: proofInputs.ethAddress.values[0],
        word_2: proofInputs.ethAddress.values[1],
        word_3: proofInputs.ethAddress.values[2],
      },
      proof_sizes_bytes: proofInputs.accountProofSizesBytes,
      proof_sizes_words: proofInputs.accountProofSizesWords,
      proofs_concat: proofInputs.accountProof,
    });

    // Obtain voting power for the account by verifying the storage proof.
    const { voting_power: vp } = await singleSlotProofStrategy.call('get_voting_power', {
      block: proofInputs.blockNumber,
      address: proofInputs.ethAddressFelt,
      params: proofInputs.votingPowerParams,
    });

    // Assert voting power obtained from strategy is correct
    expect(new SplitUint256(vp.low, vp.high)).to.deep.equal(
      SplitUint256.fromUint(BigInt(proofs.storageProof[0].value))
    );
  }).timeout(1000000);
});
