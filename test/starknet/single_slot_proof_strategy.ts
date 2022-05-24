import { starknet, ethers } from 'hardhat';
import { expect } from 'chai';
import { block } from '../data/blocks';
import { proofs } from '../data/proofs';
import { SplitUint256 } from '../shared/types';
import {
  ProofInputs,
  getProofInputs,
  ProcessBlockInputs,
  getProcessBlockInputs,
} from '../shared/parseRPCData';
import { encodeParams } from '../shared/singleSlotProofStrategyEncoding';
import { singleSlotProofSetup, Fossil } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';

// We test the single slot proof strategy flow directly here - ie not calling it via the space contract
// Full end to end tests of the flow will come soon.
describe('Single slot proof voting strategy:', () => {
  let voterAddress: string;
  let proofInputs: ProofInputs;
  let params: bigint[];
  let fossil: Fossil;
  let singleSlotProofStrategy: StarknetContract;
  let account: Account;

  before(async function () {
    this.timeout(800000);
    // Address of the user that corresponds to the slot in the contract associated with the corresponding proof
    voterAddress = '0x5773D321394D20C36E4CA35386C97761A9BAe820';

    // We pass the encode params function for the single slot proof strategy.
    proofInputs = getProofInputs(block.number, proofs, encodeParams);

    // Defining the parameters for the single slot proof strategy
    params = [proofInputs.ethAddressFelt, BigInt(0)];

    // Deploy Fossil storage verifier instance and the voting strategy contract.
    ({ fossil, singleSlotProofStrategy, account } = await singleSlotProofSetup(block));
  });

  it('The strategy should return the voting power', async () => {
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
      voter_address: { value: BigInt(voterAddress) },
      global_params: params,
      params: proofInputs.userVotingPowerParams,
    });

    // Assert voting power obtained from strategy is correct
    expect(new SplitUint256(vp.low, vp.high)).to.deep.equal(
      SplitUint256.fromUint(BigInt(proofs.storageProof[0].value))
    );
  }).timeout(1000000);
});
