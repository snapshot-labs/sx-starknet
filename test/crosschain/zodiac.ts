import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract, ContractFactory } from 'ethers';
import hre, { starknet, network, ethers, waffle } from 'hardhat';
import { Choice, SplitUint256 } from '../shared/types';
import { StarknetContract, HttpNetworkConfig, Account } from 'hardhat/types';
import { stark } from 'starknet';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { zodiacRelayerSetup } from '../shared/setup';
import {
  createExecutionHash,
  getCommit,
  flatten2DArray,
  expectAddressEquality,
  getProposeCalldata,
  getVoteCalldata,
} from '../shared/helpers';

const { getSelectorFromName } = stark;

export const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
export const VITALIK_STRING_ADDRESS = VITALIK_ADDRESS.toString(16);

// Dummy tx
const tx1 = {
  to: VITALIK_STRING_ADDRESS,
  value: 0,
  data: '0x11',
  operation: 0,
  nonce: 0,
};

// Dummy tx 2
const tx2 = {
  to: VITALIK_STRING_ADDRESS,
  value: 0,
  data: '0x22',
  operation: 0,
  nonce: 0,
};

describe('Create proposal, cast vote, and send execution to l1', function () {
  this.timeout(12000000);
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let signer: SignerWithAddress;

  // Contracts
  let mockStarknetMessaging: Contract;
  let space: StarknetContract;
  let controller: Account;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let zodiacModule: Contract;

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

  let txHashes: any;

  before(async function () {
    this.timeout(800000);
    const signers = await hre.ethers.getSigners();
    signer = signers[0];

    ({
      space,
      controller,
      vanillaAuthenticator,
      vanillaVotingStrategy,
      zodiacRelayer,
      zodiacModule,
      mockStarknetMessaging,
    } = await zodiacRelayerSetup());

    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    ({ executionHash, txHashes } = createExecutionHash(zodiacModule.address, tx1, tx2));

    proposerEthAddress = signer.address;
    ethBlockNumber = BigInt(1337);
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(zodiacRelayer.address);
    executionParams = [BigInt(zodiacModule.address)];

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

    voterEthAddress = hre.ethers.Wallet.createRandom().address;

    proposalId = BigInt(1);
    choice = Choice.FOR;
    usedVotingStrategies2 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll2 = [[]];
    voteCalldata = getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('should correctly receive and accept a finalized proposal on l1', async () => {
    this.timeout(1200000);

    // -- Creates a proposal --
    await vanillaAuthenticator.invoke('execute', {
      target: BigInt(space.address),
      function_selector: BigInt(getSelectorFromName('propose')),
      calldata: proposeCalldata,
    });

    // -- Casts a vote FOR --
    await vanillaAuthenticator.invoke('execute', {
      target: BigInt(space.address),
      function_selector: BigInt(getSelectorFromName('vote')),
      calldata: voteCalldata,
    });

    // -- Load messaging contract
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);

    // -- Finalize proposal and send execution hash to L1 --

    await space.invoke('finalize_proposal', {
      proposal_id: proposalId,
      execution_params: executionParams,
    });

    // --  Flush messages and check that communication went well --

    const flushL2Response = await starknet.devnet.flush();
    expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
    const flushL2Messages = flushL2Response.consumed_messages.from_l2;
    expect(flushL2Messages).to.have.a.lengthOf(1);
    expectAddressEquality(flushL2Messages[0].from_address, zodiacRelayer.address);
    expectAddressEquality(flushL2Messages[0].to_address, zodiacModule.address);

    // Check that l1 can receive the proposal correctly
    const proposalOutcome = BigInt(1);
    const fakeTxHashes = txHashes.slice(0, -1);
    const callerAddress = BigInt(space.address);
    const fakeCallerAddress = BigInt(zodiacRelayer.address);
    const splitExecutionHash = SplitUint256.fromHex(executionHash);

    // Check that if the tx hash is incorrect, the transaction reverts.
    await expect(
      zodiacModule.receiveProposal(
        callerAddress,
        proposalOutcome,
        splitExecutionHash.low,
        splitExecutionHash.high,
        fakeTxHashes
      )
    ).to.be.reverted;

    // Check that if `proposalOutcome` parameter is incorrect, transaction reverts.
    await expect(
      zodiacModule.receiveProposal(
        callerAddress,
        !proposalOutcome,
        splitExecutionHash.low,
        splitExecutionHash.high,
        txHashes
      )
    ).to.be.reverted;

    // Check that if `callerAddress` parameter is incorrect, transaction reverts.
    await expect(
      zodiacModule.receiveProposal(
        fakeCallerAddress,
        proposalOutcome,
        splitExecutionHash.low,
        splitExecutionHash.high,
        txHashes
      )
    ).to.be.reverted;

    // BROKEN
    // Check that it works when provided correct parameters.
    // await zodiacModule.receiveProposal(
    //   fakeCallerAddress,
    //   proposalOutcome,
    //   splitExecutionHash.low,
    //   splitExecutionHash.high,
    //   txHashes
    // );
  });
});
