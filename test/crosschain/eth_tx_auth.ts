import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { StarknetContract, HttpNetworkConfig } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { getCommit } from '../starknet/shared/helpers';
import { ethTxAuthSetup, VITALIK_STRING_ADDRESS } from '../starknet/shared/setup';
import { createExecutionHash } from '../starknet/shared/helpers';
const propose_selector = BigInt(
  '0x1BFD596AE442867EF71CA523061610682AF8B00FC2738329422F4AD8D220B81'
);
const vote_selector = BigInt('0x132BDF85FC8AA10AC3C22F02317F8F53D4B4F52235ED1EABB3A4CBBE08B5C41');
const RANDOM_ADDRESS = BigInt('0xAD4Eb63b9a2F1A4D241c92e2bBa78eEFc56ab990');

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

describe('L1 interaction with Snapshot X', function () {
  this.timeout(5000000);

  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let mockStarknetMessaging: Contract;
  let signer: SignerWithAddress;
  let space: StarknetContract;
  let ethTxAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let starknetCommit: Contract;
  let propose_calldata: bigint[];
  let vote_calldata: bigint[];

  before(async function () {
    const signers = await ethers.getSigners();
    signer = signers[0];

    // Dummy execution
    const { executionHash } = createExecutionHash(VITALIK_STRING_ADDRESS, tx1, tx2);
    const metadata_uri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    const proposal_id = BigInt(1);
    const voting_params: Array<bigint> = [];
    const eth_block_number = BigInt(1337);
    // Empty execution data
    const execution_params: Array<bigint> = [BigInt(0)];
    propose_calldata = [
      BigInt(signer.address),
      executionHash.low,
      executionHash.high,
      BigInt(metadata_uri.length),
      ...metadata_uri,
      eth_block_number,
      BigInt(voting_params.length),
      ...voting_params,
      BigInt(execution_params.length),
      ...execution_params,
    ];
    const {
      space: _space,
      ethTxAuthenticator: _ethTxAuthenticator,
      vanillaVotingStrategy: _vanillaVotingStrategy,
      mockStarknetMessaging: _mockStarknetMessaging,
      starknetCommit: _starknetCommit,
    } = await ethTxAuthSetup(signer);
    space = _space;
    ethTxAuthenticator = _ethTxAuthenticator;
    vanillaVotingStrategy = _vanillaVotingStrategy;
    mockStarknetMessaging = _mockStarknetMessaging;
    starknetCommit = _starknetCommit;
  });

  it('should create a proposal from an l1 tx', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);
    // Finding the pedersen hash of the payload
    const propose_commit = getCommit(target, propose_selector, propose_calldata);
    // Committing the hash of the payload to the StarkNet Commit L1 contract
    await starknetCommit.commit(propose_commit);
    //Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
    // Creating proposal
    await ethTxAuthenticator.invoke('execute', {
      target: target,
      function_selector: propose_selector,
      calldata: propose_calldata,
    });
  });

  it('The same commit should not be able to be executed multiple times', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);

    const propose_commit = getCommit(target, propose_selector, propose_calldata);
    await starknetCommit.commit(propose_commit);

    await starknet.devnet.flush();
    await ethTxAuthenticator.invoke('execute', {
      target: target,
      function_selector: propose_selector,
      calldata: propose_calldata,
    });
    // Second execute should fail
    try {
      await ethTxAuthenticator.invoke('execute', {
        target: target,
        function_selector: propose_selector,
        calldata: propose_calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authentication should fail if the correct hash of the payload is not committed on l1 before execution is called', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);

    // random commit
    const propose_commit = BigInt(134234123423);
    await starknetCommit.commit(propose_commit);
    await starknet.devnet.flush();
    try {
      await ethTxAuthenticator.invoke('execute', {
        target: target,
        function_selector: propose_selector,
        calldata: propose_calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authentication should fail if the commit sender address is not equal to the address in the payload', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);
    // Random l1 address in the calldata
    propose_calldata[0] = RANDOM_ADDRESS;
    const propose_commit = getCommit(target, propose_selector, propose_calldata);
    await starknetCommit.commit(propose_commit);
    await starknet.devnet.flush();
    try {
      await ethTxAuthenticator.invoke('execute', {
        target: target,
        function_selector: propose_selector,
        calldata: propose_calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Commit made by invalid L1 address');
    }
  });
});
