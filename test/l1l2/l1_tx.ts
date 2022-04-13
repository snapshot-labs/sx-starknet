import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract, ContractFactory } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { FOR, SplitUint256 } from '../starknet/shared/types';
import { StarknetContractFactory, StarknetContract, HttpNetworkConfig } from 'hardhat/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { getCommit } from '../starknet/shared/helpers';

const propose_selector = BigInt(
  '0x1BFD596AE442867EF71CA523061610682AF8B00FC2738329422F4AD8D220B81'
);
const vote_selector = BigInt('0x132BDF85FC8AA10AC3C22F02317F8F53D4B4F52235ED1EABB3A4CBBE08B5C41');
const VOTING_DELAY = BigInt(0);
const VOTING_PERIOD = BigInt(20);
const RANDOM_ADDRESS = BigInt('0xAD4Eb63b9a2F1A4D241c92e2bBa78eEFc56ab990');

export async function setup(signer: SignerWithAddress) {
  const SpaceFactory = await starknet.getContractFactory('./contracts/starknet/space/space.cairo');
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla.cairo'
  );
  const L1TxAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/l1_tx.cairo'
  );

  const MockStarknetMessagingFactory = (await ethers.getContractFactory(
    'MockStarknetMessaging',
    signer
  )) as ContractFactory;
  const mockStarknetMessaging = (await MockStarknetMessagingFactory.deploy()) as Contract;
  await mockStarknetMessaging.deployed();

  const starknetCore = mockStarknetMessaging.address;

  // Deploy StarkNet Commit L1 contract
  const StarknetCommitFactory = (await ethers.getContractFactory(
    'StarkNetCommit',
    signer
  )) as ContractFactory;
  const starknetCommit = (await StarknetCommitFactory.deploy(starknetCore)) as Contract;
  const starknet_commit = BigInt(starknetCommit.address);

  console.log('Deploying auth...');
  const l1TxAuthenticator = (await L1TxAuthenticatorFactory.deploy({
    starknet_commit_address: starknet_commit,
  })) as StarknetContract;
  console.log('Deploying strat...');
  const vanillaVotingStrategy = (await vanillaVotingStategyFactory.deploy()) as StarknetContract;
  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(l1TxAuthenticator.address);
  console.log('Deploying space...');

  // This should be declared along with the other const but doing so will make the compiler unhappy as `SplitUin256`
  // will be undefined for some reason?
  const PROPOSAL_THRESHOLD = SplitUint256.fromUint(BigInt(1));

  const space = (await SpaceFactory.deploy({
    _voting_delay: VOTING_DELAY,
    _voting_period: VOTING_PERIOD,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _voting_strategy: voting_strategy,
    _authenticator: authenticator,
  })) as StarknetContract;
  // Setting the L1 tx authenticator address in the StarkNet commit contract
  await starknetCommit.setAuth(authenticator);

  return {
    space,
    l1TxAuthenticator,
    vanillaVotingStrategy,
    mockStarknetMessaging,
    starknetCommit,
  };
}

describe('L1 interaction with Snapshot X', function () {
  this.timeout(5000000);

  const user = 1;
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let mockStarknetMessaging: Contract;
  let signer: SignerWithAddress;
  let space: StarknetContract;
  let l1TxAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let starknetCommit: Contract;
  let propose_calldata: bigint[];
  let vote_calldata: bigint[];

  before(async function () {
    const signers = await ethers.getSigners();
    signer = signers[0];

    // Proposal creation calldata
    const execution_hash = BigInt(1);
    const metadata_uri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    const proposal_id = BigInt(1);
    const params: Array<bigint> = [];
    const eth_block_number = BigInt(1337);
    propose_calldata = [
      BigInt(signer.address),
      execution_hash,
      BigInt(metadata_uri.length),
      ...metadata_uri,
      eth_block_number,
      BigInt(params.length),
      ...params,
    ];

    // Vote calldata
    vote_calldata = [BigInt(signer.address), proposal_id, FOR, BigInt(params.length), ...params];

    const {
      space: _space,
      l1TxAuthenticator: _l1TxAuthenticator,
      vanillaVotingStrategy: _vanillaVotingStrategy,
      mockStarknetMessaging: _mockStarknetMessaging,
      starknetCommit: _starknetCommit,
    } = await setup(signer);
    space = _space;
    l1TxAuthenticator = _l1TxAuthenticator;
    vanillaVotingStrategy = _vanillaVotingStrategy;
    mockStarknetMessaging = _mockStarknetMessaging;
    starknetCommit = _starknetCommit;
  });

  it('should create a proposal from an l1 tx', async () => {
    const { address: deployedTo, l1_provider: L1Provider } =
      await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);

    // Finding the pedersen hash of the payload
    const propose_commit = getCommit(target, propose_selector, propose_calldata);
    // Committing the hash of the payload to the StarkNet Commit L1 contract
    await starknetCommit.commit(propose_commit);

    //Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);

    // Creating proposal
    await l1TxAuthenticator.invoke('execute', {
      target: target,
      function_selector: propose_selector,
      calldata: propose_calldata,
    });

    // const vote_commit = getCommit(target, vote_selector, vote_calldata);
    // await starknetCommit.commit(vote_commit);
    // await starknet.devnet.flush();

    // // Casting vote
    // await l1TxAuthenticator.invoke('execute', {
    //   target: target,
    //   function_selector: vote_selector,
    //   calldata: vote_calldata,
    // });
  });

  it('The same commit should not be able to be executed multiple times', async () => {
    const { address: deployedTo, l1_provider: L1Provider } =
      await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);

    const propose_commit = getCommit(target, propose_selector, propose_calldata);
    await starknetCommit.commit(propose_commit);

    await starknet.devnet.flush();
    await l1TxAuthenticator.invoke('execute', {
      target: target,
      function_selector: propose_selector,
      calldata: propose_calldata,
    });
    // Second execute should fail
    try {
      await l1TxAuthenticator.invoke('execute', {
        target: target,
        function_selector: propose_selector,
        calldata: propose_calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authentication should fail if the correct hash of the payload is not committed on l1 before execution is called', async () => {
    const { address: deployedTo, l1_provider: L1Provider } =
      await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);

    // random commit
    const propose_commit = BigInt(134234123423);
    await starknetCommit.commit(propose_commit);
    await starknet.devnet.flush();
    try {
      await l1TxAuthenticator.invoke('execute', {
        target: target,
        function_selector: propose_selector,
        calldata: propose_calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authentication should fail if the commit sender address is not equal to the address in the payload', async () => {
    const { address: deployedTo, l1_provider: L1Provider } =
      await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    const target = BigInt(space.address);

    // Random l1 address in the calldata
    propose_calldata[0] = RANDOM_ADDRESS;
    const propose_commit = getCommit(target, propose_selector, propose_calldata);
    await starknetCommit.commit(propose_commit);
    await starknet.devnet.flush();
    try {
      await l1TxAuthenticator.invoke('execute', {
        target: target,
        function_selector: propose_selector,
        calldata: propose_calldata,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Commit made by invalid L1 address');
    }
  });
});
