import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract, ContractFactory } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { FOR, SplitUint256 } from '../starknet/shared/types';
import { StarknetContractFactory, StarknetContract, HttpNetworkConfig } from 'hardhat/types';
import { stark } from 'starknet';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { EIP712_TYPES } from '../ethereum/shared/utils';
import {
  VITALIK_ADDRESS,
  VITALIK_STRING_ADDRESS,
  setup,
  EXECUTE_METHOD,
  PROPOSAL_METHOD,
  VOTE_METHOD,
  expectAddressEquality,
} from '../starknet/shared/helpers';

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

/**
 * Utility function that returns an example executionHash and `txHashes`, given a verifying contract.
 * @param _verifyingContract The verifying l1 contract
 * @returns
 */
function createExecutionHash(_verifyingContract: string): {
  executionHash: SplitUint256;
  txHashes: Array<string>;
} {
  const domain = {
    chainId: ethers.BigNumber.from(1), //TODO: should be network.config.chainId but it's not working
    verifyingContract: _verifyingContract,
  };

  // 2 transactions in proposal
  const txHash1 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx1);
  const txHash2 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx2);

  const abiCoder = new ethers.utils.AbiCoder();
  const hash = BigInt(ethers.utils.keccak256(abiCoder.encode(['bytes32[]'], [[txHash1, txHash2]])));

  const executionHash = SplitUint256.fromUint(hash);
  return {
    executionHash,
    txHashes: [txHash1, txHash2],
  };
}

describe('Postman', function () {
  this.timeout(500000);

  const user = 1;
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
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
    L2contractFactory = await starknet.getContractFactory('./contracts/starknet/space/space.cairo');

    const {
      vanillaSpace: _spaceContract,
      vanillaAuthenticator: _authContract,
      vanillaVotingStrategy: _votingContract,
    } = await setup();
    spaceContract = _spaceContract;
    authContract = _authContract;
    votingContract = _votingContract;

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
    const decisionExecutor = spaceContract.address;
    l1ExecutorFactory = await ethers.getContractFactory('SnapshotXL1Executor', signer);
    l1Executor = await l1ExecutorFactory.deploy(
      owner,
      avatar,
      target,
      starknetCore,
      decisionExecutor
    );
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

  it('should corectly receive and accept a finalized proposal on l1', async () => {
    const { executionHash, txHashes } = createExecutionHash(l1Executor.address);
    const metadata_uri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    const proposer_address = VITALIK_ADDRESS;
    const proposal_id = 1;
    const params: Array<bigint> = [];
    const eth_block_number = BigInt(1337);
    const calldata = [
      proposer_address,
      executionHash.low,
      executionHash.high,
      BigInt(metadata_uri.length),
      ...metadata_uri,
      eth_block_number,
      BigInt(params.length),
      ...params,
    ];

    // -- Sets the l1 executor --
    {
      await spaceContract.invoke('set_l1_executor', { _l1_executor: BigInt(l1Executor.address) });
    }

    // -- Creates a proposal --
    await authContract.invoke(EXECUTE_METHOD, {
      to: BigInt(spaceContract.address),
      function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
      calldata,
    });

    // -- Casts a vote FOR --
    {
      const voter_address = proposer_address;
      const params: Array<BigInt> = [];
      await authContract.invoke(EXECUTE_METHOD, {
        to: BigInt(spaceContract.address),
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [voter_address, proposal_id, FOR, BigInt(params.length)],
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
      await spaceContract.invoke('finalize_proposal', { proposal_id: proposal_id });
    }

    // --  Flush messages and check that communication went well --
    {
      const flushL2Response = await starknet.devnet.flush();
      expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
      const flushL2Messages = flushL2Response.consumed_messages.from_l2;

      expect(flushL2Messages).to.have.a.lengthOf(1);
      expectAddressEquality(flushL2Messages[0].from_address, spaceContract.address);
      expectAddressEquality(flushL2Messages[0].to_address, l1Executor.address);
    }

    // Check that l1 can receive the proposal correctly
    {
      const hasPassed = BigInt(1);

      const fakeTxHashes = txHashes.slice(0, -1);
      // Check that if the tx hash is incorrect, the transaction reverts.
      await expect(
        l1Executor.receiveProposal(executionHash.low, executionHash.high, hasPassed, fakeTxHashes)
      ).to.be.reverted;

      // Check that if `hasPassed` parameter is incorrect, transaction reverts.
      await expect(
        l1Executor.receiveProposal(executionHash.low, executionHash.high, !hasPassed, txHashes)
      ).to.be.reverted;

      // Check that it works when provided correct parameters.
      await l1Executor.receiveProposal(executionHash.low, executionHash.high, hasPassed, txHashes);
    }
  });
});
