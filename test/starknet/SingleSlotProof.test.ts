import fs from 'fs';
import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { SplitUint256, Choice } from '../shared/types';
import { ProofInputs } from '../shared/parseRPCData';
import { singleSlotProofSetup, Fossil } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { getProposeCalldata, getVoteCalldata, bytesToHex } from '../shared/helpers';
import { StarknetContract, Account } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';

describe('Single slot proof voting strategy:', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let account: Account;
  let vanillaAuthenticator: StarknetContract;
  let singleSlotProofStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let fossil: Fossil;

  // Data for account and storage proofs
  let proofInputs: ProofInputs;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let executionHash: string;
  let metadataUri: bigint[];
  let proposerEthAddress: string;
  let usedVotingStrategies1: bigint[];
  let userVotingParamsAll1: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
  let proposeCalldata: bigint[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: bigint;
  let choice: Choice;
  let usedVotingStrategies2: bigint[];
  let userVotingParamsAll2: bigint[][];
  let voteCalldata: bigint[];

  before(async function () {
    this.timeout(800000);

    const block = JSON.parse(fs.readFileSync('./test/data/block.json').toString());
    const proofs = JSON.parse(fs.readFileSync('./test/data/proofs.json').toString());

    account = await starknet.deployAccount('Argent');

    ({
      space,
      controller,
      vanillaAuthenticator,
      singleSlotProofStrategy,
      vanillaExecutionStrategy,
      fossil,
      proofInputs,
    } = await singleSlotProofSetup(block, proofs));

    proposalId = BigInt(1);
    executionHash = bytesToHex(ethers.utils.randomBytes(32)); // Random 32 byte hash
    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    // Eth address corresponding to slot with key: 0x1f209fa834e9c9c92b83d1bd04d8d1914bd212e440f88fdda8a5879962bda665
    proposerEthAddress = '0x4048c47b546b68ad226ea20b5f0acac49b086a21';
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(singleSlotProofStrategy.address)];
    userVotingParamsAll1 = [proofInputs.storageProofs[0]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );
    // Eth address corresponding to slot with key: 0x9dd2a912bd3f98d4e52ea66ae2fff8b73a522895d081d522fe86f592ec8467c3
    voterEthAddress = '0x3744da57184575064838bbc87a0fc791f5e39ea2';
    choice = Choice.FOR;
    usedVotingStrategies2 = [BigInt(singleSlotProofStrategy.address)];
    userVotingParamsAll2 = [proofInputs.storageProofs[1]];
    voteCalldata = getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('A user can create a proposal', async () => {
    // Verify an account proof to obtain the storage root for the account at the specified block number trustlessly on-chain.
    // Result will be stored in the L1 Headers store in Fossil
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

    // -- Creates the proposal --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _executionHash = SplitUint256.fromObj(proposal_info.proposal.execution_hash).toUint();
      expect(_executionHash).to.deep.equal(BigInt(executionHash));
      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
      console.log('proposal created');
    }

    // -- Casts a vote FOR --
    {
      await vanillaAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
      });

      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt('0x26d16aea9a19cda40000'));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // -- Executes the proposal --
    {
      await space.invoke('finalize_proposal', {
        proposal_id: proposalId,
        execution_params: executionParams,
      });
    }
  }).timeout(1000000);
});
