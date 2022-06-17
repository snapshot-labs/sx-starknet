import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { StarknetContract, Account, HttpNetworkConfig } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { getCommit, getProposeCalldata } from '../shared/helpers';
import { ethTxAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR } from '../shared/constants';

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
  let metadataUri: bigint[];
  let proposerEthAddress: string;
  let usedVotingStrategies: bigint[];
  let userVotingParamsAll: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
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

    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    proposerEthAddress = signer.address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll = [[]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposeCalldata = getProposeCalldata(
      proposerEthAddress,
      metadataUri,
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
      .commit(getCommit(spaceAddress, PROPOSE_SELECTOR, proposeCalldata));
    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
    // Creating proposal
    await ethTxAuthenticator.invoke('authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });
  });

  it('The same commit should not be able to be executed multiple times', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    await starknetCommit
      .connect(signer)
      .commit(getCommit(spaceAddress, PROPOSE_SELECTOR, proposeCalldata));
    await starknet.devnet.flush();
    await ethTxAuthenticator.invoke('authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });
    // Second attempt at calling authenticate should fail
    try {
      await ethTxAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
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
      .commit(getCommit(spaceAddress, PROPOSE_SELECTOR, proposeCalldata)); // Wrong selector
    await starknet.devnet.flush();
    try {
      await ethTxAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
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
      .commit(getCommit(spaceAddress, PROPOSE_SELECTOR, proposeCalldata));
    await starknet.devnet.flush();
    try {
      await ethTxAuthenticator.invoke('authenticate', {
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Commit made by invalid L1 address');
    }
  });
});
