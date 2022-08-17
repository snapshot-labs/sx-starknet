import fs from 'fs';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { singleSlotProofSetup, Fossil } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { StarknetContract, Account } from 'hardhat/types';
// import { strToShortStringArr } from '@snapshot-labs/sx';
import { utils } from '@snapshot-labs/sx';

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
  let proofInputs: utils.storageProofs.ProofInputs;

  // Proposal creation parameters
  let spaceAddress: string;
  let metadataUri: utils.intsSequence.IntsSequence;
  let proposerEthAddress: string;
  let usedVotingStrategies1: string[];
  let userVotingParamsAll1: string[][];
  let executionStrategy: string;
  let executionParams: string[];
  let proposeCalldata: string[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let userVotingParamsAll2: string[][];
  let voteCalldata: string[];

  before(async function () {
    this.timeout(800000);

    const block = JSON.parse(fs.readFileSync('./test/data/block.json').toString());
    const proofs = JSON.parse(fs.readFileSync('./test/data/proofs.json').toString());

    account = await starknet.deployAccount('OpenZeppelin');

    ({
      space,
      controller,
      vanillaAuthenticator,
      singleSlotProofStrategy,
      vanillaExecutionStrategy,
      fossil,
      proofInputs,
    } = await singleSlotProofSetup(block, proofs));

    proposalId = '0x1';
    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    // Eth address corresponding to slot with key: 0x1f209fa834e9c9c92b83d1bd04d8d1914bd212e440f88fdda8a5879962bda665
    proposerEthAddress = '0x4048c47b546b68ad226ea20b5f0acac49b086a21';
    spaceAddress = space.address;
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [proofInputs.storageProofs[0]];
    executionStrategy = vanillaExecutionStrategy.address;
    executionParams = [];
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );
    // Eth address corresponding to slot with key: 0x9dd2a912bd3f98d4e52ea66ae2fff8b73a522895d081d522fe86f592ec8467c3
    voterEthAddress = '0x3744da57184575064838bbc87a0fc791f5e39ea2';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [proofInputs.storageProofs[1]];
    voteCalldata = utils.encoding.getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('A user can create a proposal and another user can vote on it', async () => {
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

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
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

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt('0x26d16aea9a19cda40000'));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
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
