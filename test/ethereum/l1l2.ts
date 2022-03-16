import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, Contract, ContractFactory } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { SplitUint256, AGAINST, FOR, ABSTAIN } from '../starknet/shared/types';
import {
  StarknetContractFactory,
  StarknetContract,
  HttpNetworkConfig,
} from 'hardhat/types';
import { stark } from 'starknet';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { executeContractCallWithSigners, buildContractCall, EIP712_TYPES } from './shared/utils';

const { getSelectorFromName } = stark;

const EXECUTE_METHOD = 'execute';
const PROPOSAL_METHOD = 'propose';
const VOTE_METHOD = 'vote';
const GET_PROPOSAL_INFO = 'get_proposal_info';
const GET_VOTE_INFO = 'get_vote_info';
const VOTING_DELAY = BigInt(0);
const VOTING_PERIOD = BigInt(20);
const PROPOSAL_THRESHOLD = SplitUint256.fromUint(BigInt(1));
const VITALIK_ADDRESS = BigInt(0xd8da6bf26964af9d7eed9e03e53415d37aa96045);
const VITALIK_STRING_ADDRESS = "0xd8da6bf26964af9d7eed9e03e53415d37aa96045";

export async function setup() {
  const vanillaSpaceFactory = await starknet.getContractFactory(
    './contracts/starknet/space/space.cairo'
  );
  const vanillaVotingStategyFactory = await starknet.getContractFactory(
    './contracts/starknet/strategies/vanilla_voting_strategy.cairo'
  );
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/authenticator.cairo'
  );
  console.log('Deploying auth...');
  const vanillaAuthenticator = (await vanillaAuthenticatorFactory.deploy()) as StarknetContract;
  console.log('Deploying strat...');
  const vanillaVotingStrategy = (await vanillaVotingStategyFactory.deploy()) as StarknetContract;
  const voting_strategy = BigInt(vanillaVotingStrategy.address);
  const authenticator = BigInt(vanillaAuthenticator.address);
  console.log('Deploying space...');
  const vanillaSpace = (await vanillaSpaceFactory.deploy({
    _voting_delay: VOTING_DELAY,
    _voting_period: VOTING_PERIOD,
    _proposal_threshold: PROPOSAL_THRESHOLD,
    _voting_strategy: voting_strategy,
    _authenticator: authenticator,
    _l1_executor: BigInt(0x1234),
  })) as StarknetContract;

  return {
    vanillaSpace,
    vanillaAuthenticator,
    vanillaVotingStrategy,
  };
}

const tx1 = {
  to: VITALIK_STRING_ADDRESS,
  value: 0,
  data: '0x11',
  operation: 0,
  nonce: 0,
};

const tx2 = {
  to: VITALIK_STRING_ADDRESS,
  value: 0,
  data: '0x22',
  operation: 0,
  nonce: 0,
};

function createExecutionHash(_verifyingContract: string): {executionHash: string, txHashes: Array<string>} {
  const domain = {
    chainId: ethers.BigNumber.from(1), // network.config.chainId
    verifyingContract: _verifyingContract,
  };
  console.log("a");

  //2 transactions in proposal
  const tx_hash1 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx1);
  console.log("b");
  const tx_hash2 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx2);
  console.log("c");

  const abiCoder = new ethers.utils.AbiCoder();
  const hash = ethers.utils.keccak256(abiCoder.encode(['bytes32[]'], [[tx_hash1, tx_hash2]]))
  const executionHash = "";
  return {
    executionHash,
    txHashes: [tx_hash1, tx_hash2]}
}

/**
 * Receives a hex address, converts it to bigint, converts it back to hex.
 * This is done to strip leading zeros.
 * @param address a hex string representation of an address
 * @returns an adapted hex string representation of the address
 */
function adaptAddress(address: string) {
    return "0x" + BigInt(address).toString(16);
}
  
/**
 * Expects address equality after adapting them.
 * @param actual 
 * @param expected 
 */
function expectAddressEquality(actual: string, expected: string) {
    expect(adaptAddress(actual)).to.equal(adaptAddress(expected));
}

describe('Postman', function() {
    this.timeout(500000);
  
    const user = 1;
    const networkUrl: string = (network.config as HttpNetworkConfig).url;
    // const networkUrl = "http://127.0.0.1:8545";
    let L2contractFactory: StarknetContractFactory;
    let l1ExecutorFactory: ContractFactory;
    let MockStarknetMessaging: ContractFactory;
    let mockStarknetMessaging: Contract;
    let l1Executor: Contract;
    let signer: SignerWithAddress;
    let spaceContract: StarknetContract;
    let authContract: StarknetContract;
    let votingContract: StarknetContract;
  
    before(async function () {
      L2contractFactory = await starknet.getContractFactory(
          './contracts/starknet/space/space.cairo'
        );

      let {vanillaSpace: _spaceContract, vanillaAuthenticator: _authContract, vanillaVotingStrategy: _votingContract} = await setup();
      spaceContract = _spaceContract;
      authContract = _authContract;
      votingContract = _votingContract;

      const signers = await ethers.getSigners();
      signer = signers[0];
  
      console.log("Mock Starknet Messaging factory...");
      MockStarknetMessaging = await ethers.getContractFactory(
        'MockStarknetMessaging',
        signer,
      ) as ContractFactory;
      console.log("Mock Starknet Messaging deploying...");
      mockStarknetMessaging = await MockStarknetMessaging.deploy();
      console.log("Mock Starknet Messaging deploying?...");
      await mockStarknetMessaging.deployed();
      console.log("Mock Starknet deployed...");
  
      const owner = signer.address;
      const avatar = signer.address; // todo
      const target = signer.address; // todo
      const starknetCore = mockStarknetMessaging.address;
      const decisionExecutor = spaceContract.address;
      l1ExecutorFactory = await ethers.getContractFactory(
            'SnapshotXL1Executor',
            signer
        );
      console.log("deploying l1 Executor...");
      l1Executor = await l1ExecutorFactory.deploy(
          owner,
          avatar,
          target,
          starknetCore,
          decisionExecutor
        );
      console.log("awaited");
      await l1Executor.deployed();
      console.log("deployed!");

      console.log("set l1 executor", l1Executor.address);
      await spaceContract.invoke("set_l1_executor", {_l1_executor: BigInt(l1Executor.address)});
      console.log("set");
      console.log("URL : ", networkUrl);
    });
  
    it('should deploy the messaging contract', async () => {
      const {
        address: deployedTo,
        l1_provider: L1Provider,
      } = await starknet.devnet.loadL1MessagingContract(networkUrl);
  
  
      expect(deployedTo).not.to.be.undefined;
      expect(L1Provider).to.equal(networkUrl);
    });
  
    it('should load the already deployed contract if the address is provided', async () => {
  
      const {
        address: loadedFrom,
      } = await starknet.devnet.loadL1MessagingContract(
        networkUrl,
        mockStarknetMessaging.address,
      );
  
      expect(mockStarknetMessaging.address).to.equal(loadedFrom);
    });

    it('should set the l1 executor address', async () => {
    });
  
    it('should exchange messages between L1 and L2', async () => {
      /**
       * Load the mock messaging contract
       */
       const {executionHash, txHashes} = createExecutionHash(l1Executor.address);
       console.log("executionHash: ", executionHash);
       console.log("txHashes: ", txHashes);
       const metadata_uri = strToShortStringArr(
         'Hello and welcome to Snapshot X. This is the future of governance.'
       );
       const proposer_address = VITALIK_ADDRESS;
       const proposal_id = 1;
       const params: Array<bigint> = [];
       const eth_block_number = BigInt(1337);
       const calldata = [
         proposer_address,
         BigInt(executionHash),
         BigInt(metadata_uri.length),
         ...metadata_uri,
         eth_block_number,
         BigInt(params.length),
         ...params,
       ];

      await spaceContract.invoke("set_l1_executor", {_l1_executor: BigInt(l1Executor.address)});
      const {executor_address: l1Exec} = await spaceContract.call("get_l1_executor", {});
      console.log("0x" + l1Exec.value.toString(16));
      console.log(l1Executor.address);
   
       // -- Creates the proposal --
       {
         console.log('Creating proposal...');
         await authContract.invoke(EXECUTE_METHOD, {
           to: BigInt(spaceContract.address),
           function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
           calldata,
         });
       }
   
       // -- Casts a vote FOR --
       {
         const voter_address = proposer_address;
         const params: Array<BigInt> = [];
         console.log('Voting FOR...');
         await authContract.invoke(EXECUTE_METHOD, {
           to: BigInt(spaceContract.address),
           function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
           calldata: [voter_address, proposal_id, FOR, BigInt(params.length)],
         });
   
         console.log('Getting proposal info...');
         const { proposal_info } = await spaceContract.call('get_proposal_info', {
           proposal_id: proposal_id,
         });
         console.log(proposal_info);
       }
  
      await starknet.devnet.loadL1MessagingContract(
        networkUrl,
        mockStarknetMessaging.address,
      );

      // -- Finalize proposal and send execution details to L1 --
      {
        await spaceContract.invoke("finalize_proposal", {proposal_id: proposal_id});
      }
  
      /**
       * Flushing the L2 messages so that they can be consumed by the L1.
       */
  
      console.log("flushing 1");
      const flushL2Response = await starknet.devnet.flush();
      expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
      const flushL2Messages = flushL2Response.consumed_messages.from_l2;
  
      expect(flushL2Messages).to.have.a.lengthOf(1);
      expectAddressEquality(flushL2Messages[0].from_address, spaceContract.address);
      expectAddressEquality(flushL2Messages[0].to_address, l1Executor.address);
      console.log("after flushing 1");
  
      let hasPassed = BigInt(1);
      await l1Executor.receiveProposal(executionHash, hasPassed, txHashes);
      console.log("after");
  
    //   await l1Executor.withdraw(l2contract.address, user, 10);
    //   userL1Balance = await l1l2Example.userBalances(user);
  
    //   expect(userL1Balance.eq(10)).to.be.true;
  
      /**
       * Check if L2 balance increased after the deposit
       */
  
    //   userL2Balance = await l2contract.call('get_balance', {
    //     user,
    //   });
  
    //   expect(userL2Balance).to.deep.equal({ balance: BigInt(90) });
  
      /**
       * Flushing the L1 messages so that they can be consumed by the L2.
       */
  
      const flushL1Response = await starknet.devnet.flush();
      const flushL1Messages = flushL1Response.consumed_messages.from_l1;
      console.log("len");
      expect(flushL1Messages).to.have.a.lengthOf(1);
      console.log("len2");
      expect(flushL1Response.consumed_messages.from_l2).to.be.empty;
  
      expectAddressEquality(flushL1Messages[0].args.from_address, l1Executor.address);
      expectAddressEquality(flushL1Messages[0].args.to_address, spaceContract.address);
      expectAddressEquality(flushL1Messages[0].address, mockStarknetMessaging.address);
    });
  });