import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract, ContractFactory } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { FOR, SplitUint256 } from '../starknet/shared/types';
import { StarknetContractFactory, StarknetContract, HttpNetworkConfig } from 'hardhat/types';
import { stark } from 'starknet';
import { strToShortStringArr } from '@snapshot-labs/sx';
import {
  VITALIK_ADDRESS,
  VITALIK_STRING_ADDRESS,
  vanillaSetup,
  EXECUTE_METHOD,
  PROPOSAL_METHOD,
  VOTE_METHOD,
} from '../starknet/shared/setup';
import { expectAddressEquality, createExecutionHash } from '../starknet/shared/helpers';

const { getSelectorFromName } = stark;

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
  let l1ExecutorFactory: ContractFactory;
  let MockStarknetMessaging: ContractFactory;
  let mockStarknetMessaging: Contract;
  let l1Executor: Contract;
  let signer: SignerWithAddress;
  let spaceContract: StarknetContract;
  let authContract: StarknetContract;
  let votingContract: StarknetContract;
  let zodiacRelayer: StarknetContract;

  before(async function () {
    this.timeout(800000);

    ({
      vanillaSpace: spaceContract,
      vanillaAuthenticator: authContract,
      vanillaVotingStrategy: votingContract,
      zodiacRelayer,
    } = await vanillaSetup());

    const signers = await ethers.getSigners();
    signer = signers[0];

    MockStarknetMessaging = (await ethers.getContractFactory(
      'MockStarknetMessaging',
      signer
    )) as ContractFactory;
    mockStarknetMessaging = await MockStarknetMessaging.deploy();
    await mockStarknetMessaging.deployed();

    const owner = signer.address;
    const avatar = signer.address; // Dummy
    const target = signer.address; // Dummy
    const starknetCore = mockStarknetMessaging.address;
    const relayer = BigInt(zodiacRelayer.address);
    l1ExecutorFactory = await ethers.getContractFactory('SnapshotXL1Executor', signer);
    l1Executor = await l1ExecutorFactory.deploy(owner, avatar, target, starknetCore, relayer, [
      BigInt(spaceContract.address),
    ]);
    await l1Executor.deployed();
  });

  it('should deploy the messaging contract', async () => {
    const { address: deployedTo, l1_provider: L1Provider } =
      await starknet.devnet.loadL1MessagingContract(networkUrl);
    expect(deployedTo).not.to.be.undefined;
    expect(L1Provider).to.equal(networkUrl);
  });

  it('should load the already deployed contract if the address is provided', async () => {
    const { address: loadedFrom } = await starknet.devnet.loadL1MessagingContract(
      networkUrl,
      mockStarknetMessaging.address
    );

    expect(mockStarknetMessaging.address).to.equal(loadedFrom);
  });

  it('should correctly receive and accept a finalized proposal on l1', async () => {
    this.timeout(1200000);
    const { executionHash, txHashes } = createExecutionHash(l1Executor.address, tx1, tx2);
    const metadata_uri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    const proposer_address = VITALIK_ADDRESS;
    const proposal_id = BigInt(1);
    const voting_params: Array<bigint> = [];
    const eth_block_number = BigInt(1337);
    const execution_params: Array<bigint> = [BigInt(l1Executor.address)];
    const calldata = [
      proposer_address,
      executionHash.low,
      executionHash.high,
      BigInt(metadata_uri.length),
      ...metadata_uri,
      eth_block_number,
      BigInt(voting_params.length),
      ...voting_params,
      BigInt(execution_params.length),
      execution_params,
    ];

    // -- Creates a proposal --
    await authContract.invoke(EXECUTE_METHOD, {
      target: BigInt(spaceContract.address),
      function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
      calldata,
    });

    // -- Casts a vote FOR --
    {
      const voter_address = proposer_address;
      const votingParams: Array<BigInt> = [];
      await authContract.invoke(EXECUTE_METHOD, {
        target: BigInt(spaceContract.address),
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [voter_address, proposal_id, FOR, BigInt(votingParams.length), ...votingParams],
      });

      const { proposal_info } = await spaceContract.call('get_proposal_info', {
        proposal_id: proposal_id,
      });
    }

    // -- Load messaging contract
    {
      await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    }

    // -- Finalize proposal and send execution hash to L1 --
    {
      await spaceContract.invoke('finalize_proposal', {
        proposal_id: proposal_id,
        execution_params: [BigInt(l1Executor.address)],
      });
    }

    // --  Flush messages and check that communication went well --
    {
      const flushL2Response = await starknet.devnet.flush();
      expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
      const flushL2Messages = flushL2Response.consumed_messages.from_l2;

      expect(flushL2Messages).to.have.a.lengthOf(1);
      expectAddressEquality(flushL2Messages[0].from_address, zodiacRelayer.address);
      expectAddressEquality(flushL2Messages[0].to_address, l1Executor.address);
    }

    // Check that l1 can receive the proposal correctly
    {
      const proposalOutcome = BigInt(1);

      const fakeTxHashes = txHashes.slice(0, -1);
      const callerAddress = BigInt(spaceContract.address);
      const fakeCallerAddress = BigInt(zodiacRelayer.address);
      // Check that if the tx hash is incorrect, the transaction reverts.
      await expect(
        l1Executor.receiveProposal(
          callerAddress,
          proposalOutcome,
          executionHash.low,
          executionHash.high,
          fakeTxHashes
        )
      ).to.be.reverted;

      // Check that if `proposalOutcome` parameter is incorrect, transaction reverts.
      await expect(
        l1Executor.receiveProposal(
          callerAddress,
          !proposalOutcome,
          executionHash.low,
          executionHash.high,
          txHashes
        )
      ).to.be.reverted;

      // Check that if `callerAddress` parameter is incorrect, transaction reverts.
      await expect(
        l1Executor.receiveProposal(
          fakeCallerAddress,
          proposalOutcome,
          executionHash.low,
          executionHash.high,
          txHashes
        )
      ).to.be.reverted;

      // Check that it works when provided correct parameters.
      await l1Executor.receiveProposal(
        callerAddress,
        proposalOutcome,
        executionHash.low,
        executionHash.high,
        txHashes
      );
    }
  });
});
