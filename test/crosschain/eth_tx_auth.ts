import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { StarknetContract, Account, HttpNetworkConfig } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
<<<<<<< HEAD
import {
  createExecutionHash,
  getCommit,
  flatten2DArray,
  getProposeCalldata,
} from '../shared/helpers';
import { ethTxAuthSetup } from '../shared/setup';
import { proposeSelector, voteSelector } from '../shared/constants';
=======
import { getCommit, flatten2DArray } from '../starknet/shared/helpers';
import { ethTxAuthSetup, VITALIK_ADDRESS, VITALIK_STRING_ADDRESS } from '../starknet/shared/setup';
import { createExecutionHash } from '../starknet/shared/helpers';
const propose_selector = BigInt(
  '0x1BFD596AE442867EF71CA523061610682AF8B00FC2738329422F4AD8D220B81'
);
const vote_selector = BigInt('0x132BDF85FC8AA10AC3C22F02317F8F53D4B4F52235ED1EABB3A4CBBE08B5C41');
const RANDOM_ADDRESS = BigInt('0xAD4Eb63b9a2F1A4D241c92e2bBa78eEFc56ab990');
>>>>>>> 52b2f15d36774198b2d33e8847367858a686421c

// Dummy tx
const tx1 = {
  to: ethers.Wallet.createRandom().address,
  value: 0,
  data: '0x11',
  operation: 0,
  nonce: 0,
};

// Dummy tx 2
const tx2 = {
  to: ethers.Wallet.createRandom().address,
  value: 0,
  data: '0x22',
  operation: 0,
  nonce: 0,
};

describe('L1 interaction with Snapshot X', function () {
  this.timeout(5000000);
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let signer: SignerWithAddress;

  // Contracts
  let mockStarknetMessaging: Contract;
  let space: StarknetContract;
  let controller: Account;
  let ethTxAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let starknetCommit: Contract;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let executionHash: string;
  let metadataUri: bigint[];
  let proposerEthAddress: string;
  let usedVotingStrategies: bigint[];
  let userVotingParamsAll: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
  let ethBlockNumber: bigint;
  let proposeCalldata: bigint[];

  before(async function () {
    const signers = await ethers.getSigners();
    signer = signers[0];

    ({
      space,
      controller,
      ethTxAuthenticator,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
      mockStarknetMessaging,
      starknetCommit,
    } = await ethTxAuthSetup());

    ({ executionHash } = createExecutionHash(ethers.Wallet.createRandom().address, tx1, tx2));
    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = signer.address;
    ethBlockNumber = BigInt(1337);
    spaceAddress = BigInt(space.address);
    usedVotingStrategies = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll = [[]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      ethBlockNumber,
      executionStrategy,
      usedVotingStrategies,
      userVotingParamsAll,
      executionParams
    );
  });

  it('should create a proposal from an l1 tx', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    // Committing the hash of the payload to the StarkNet Commit L1 contract
    await starknetCommit
      .connect(signer)
      .commit(getCommit(BigInt(space.address), proposeSelector, proposeCalldata));
    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
    // Creating proposal
    await ethTxAuthenticator.invoke('execute', {
      target: BigInt(space.address),
      function_selector: proposeSelector,
      calldata: proposeCalldata,
    });
  });

  it('The same commit should not be able to be executed multiple times', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    await starknetCommit
      .connect(signer)
      .commit(getCommit(BigInt(space.address), proposeSelector, proposeCalldata));
    await starknet.devnet.flush();
    await ethTxAuthenticator.invoke('execute', {
      target: BigInt(space.address),
      function_selector: proposeSelector,
      calldata: proposeCalldata,
    });
    // Second attempt at calling execute should fail
    try {
      await ethTxAuthenticator.invoke('execute', {
        target: BigInt(space.address),
        function_selector: proposeSelector,
        calldata: proposeCalldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authentication should fail if the correct hash of the payload is not committed on l1 before execution is called', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    await starknetCommit
      .connect(signer)
      .commit(getCommit(BigInt(space.address), voteSelector, proposeCalldata)); // Wrong selector
    await starknet.devnet.flush();
    try {
      await ethTxAuthenticator.invoke('execute', {
        target: BigInt(space.address),
        function_selector: proposeSelector,
        calldata: proposeCalldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authentication should fail if the commit sender address is not equal to the address in the payload', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    proposeCalldata[0] = BigInt(ethers.Wallet.createRandom().address); // Random l1 address in the calldata
    await starknetCommit
      .connect(signer)
      .commit(getCommit(BigInt(space.address), proposeSelector, proposeCalldata));
    await starknet.devnet.flush();
    try {
      await ethTxAuthenticator.invoke('execute', {
        target: BigInt(space.address),
        function_selector: proposeSelector,
        calldata: proposeCalldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Commit made by invalid L1 address');
    }
  });
});
