import { expect } from 'chai';
import { starknet, ethers } from 'hardhat';
import { stark } from 'starknet';
// import { block } from '../data/blocks1';
// import { proofs } from '../data/proofs1';
import fs from 'fs';
import { SplitUint256, Choice } from '../shared/types';
import { ProofInputs, getProofInputs } from '../shared/parseRPCData';
import { encodeParams } from '../shared/singleSlotProofStrategyEncoding';
import { singleSlotProofSetup, Fossil } from '../shared/setup';
import { getProposeCalldata, getVoteCalldata, bytesToHex } from '../shared/helpers';
import { StarknetContract, OpenZeppelinAccount, ArgentAccount, Account } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';

const { getSelectorFromName } = stark;

// We test the single slot proof strategy flow directly here - ie not calling it via the space contract
// Full end to end tests of the flow will come soon.
describe('Single slot proof voting strategy:', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let account: Account;
  let vanillaAuthenticator: StarknetContract;
  let singleSlotProofStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let fossil: Fossil;

  let proposerAddress: string;
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
  let ethBlockNumber: bigint;
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

    // const account2 = (await starknet.deployAccount("Argent")) as ArgentAccount;
    account = await starknet.deployAccount('Argent');

    // Address of the user that corresponds to the slot in the contract associated with the corresponding proof
    // proposerAddress = '0x5773D321394D20C36E4CA35386C97761A9BAe820';

    // Deploy Fossil storage verifier instance and the voting strategy contract.
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
    ethBlockNumber = BigInt(1337);
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(singleSlotProofStrategy.address)];
    userVotingParamsAll1 = [proofInputs.userVotingPowerParams];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      ethBlockNumber,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );
    // Eth address corresponding to slot with key: 0x9dd2a912bd3f98d4e52ea66ae2fff8b73a522895d081d522fe86f592ec8467c3
    voterEthAddress = '0x3744da57184575064838bbc87a0fc791f5e39ea2';
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
      await vanillaAuthenticator.invoke('execute', {
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName('propose')),
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
    }
  }).timeout(1000000);

  it('A user cannot create a proposal if they do not exceed the proposal threshold of voting power create a proposal', async () => {}).timeout(
    1000000
  );
});
