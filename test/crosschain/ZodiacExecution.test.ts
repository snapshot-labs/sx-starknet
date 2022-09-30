import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import hre, { starknet, network } from 'hardhat';
import { StarknetContract, HttpNetworkConfig, Account, Wallet } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { zodiacRelayerSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

const VITALIK_ADDRESS = 'd8da6bf26964af9d7eed9e03e53415d37aa96045'; //removed hex prefix

// Dummy tx
const tx1: utils.encoding.MetaTransaction = {
  to: VITALIK_ADDRESS,
  value: 0,
  data: '0x11',
  operation: 0,
  nonce: 0,
};

// Dummy tx 2
const tx2: utils.encoding.MetaTransaction = {
  to: VITALIK_ADDRESS,
  value: 0,
  data: '0x22',
  operation: 0,
  nonce: 0,
};

describe('Create proposal, cast vote, and send execution to l1', function () {
  this.timeout(12000000);
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let signer: SignerWithAddress;
  let relayerWallet: Wallet;

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

    metadataUri = utils.intsSequence.IntsSequence.LEFromString(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    ({ executionHash, txHashes } = utils.encoding.createExecutionHash(
      [tx1, tx2],
      zodiacModule.address,
      network.config.chainId!
    ));

    proposerEthAddress = signer.address;
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy = zodiacRelayer.address;
    executionParams = [
      zodiacModule.address,
      utils.splitUint256.SplitUint256.fromHex(executionHash).low,
      utils.splitUint256.SplitUint256.fromHex(executionHash).high,
    ];

    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = hre.ethers.Wallet.createRandom().address;

    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [[]];
    voteCalldata = utils.encoding.getVoteCalldata(
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
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: PROPOSE_SELECTOR,
      calldata: proposeCalldata,
    });

    // -- Casts a vote FOR --
    await controller.invoke(vanillaAuthenticator, 'authenticate', {
      target: spaceAddress,
      function_selector: VOTE_SELECTOR,
      calldata: voteCalldata,
    });

    // // -- Load messaging contract
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    await starknet.devnet.loadL1MessagingContract(networkUrl);
    // -- Finalize proposal and send execution hash to L1 --

    await controller.invoke(space, 'finalize_proposal', {
      proposal_id: proposalId,
      execution_params: executionParams,
    });

    // --  Flush messages and check that communication went well --

    const flushL2Response = await starknet.devnet.flush();
    expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
    const flushL2Messages = flushL2Response.consumed_messages.from_l2;
    expect(flushL2Messages).to.have.a.lengthOf(1);
    expect(BigInt(flushL2Messages[0].from_address)).to.equal(BigInt(zodiacRelayer.address));
    expect(BigInt(flushL2Messages[0].to_address)).to.equal(BigInt(zodiacModule.address));

    // -- Check that l1 can receive the proposal correctly --

    const proposalOutcome = BigInt(1);
    const fakeTxHashes = txHashes.slice(0, -1);
    const callerAddress = BigInt(space.address);
    const fakeCallerAddress = BigInt(zodiacRelayer.address);
    const splitExecutionHash = utils.splitUint256.SplitUint256.fromHex(executionHash);

    // Check that if the tx hash is incorrect, the transaction reverts.
    await expect(
      zodiacModule.receiveProposal(
        callerAddress,
        proposalOutcome,
        splitExecutionHash.low,
        splitExecutionHash.high,
        fakeTxHashes
      )
    ).to.be.revertedWith('Invalid execution');

    // Check that if `proposalOutcome` parameter is incorrect, transaction reverts.
    await expect(
      zodiacModule.receiveProposal(
        callerAddress,
        0,
        splitExecutionHash.low,
        splitExecutionHash.high,
        txHashes
      )
    ).to.be.revertedWith('Proposal did not pass');

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

    // Check that it works when provided correct parameters.
    await zodiacModule.receiveProposal(
      callerAddress,
      proposalOutcome,
      splitExecutionHash.low,
      splitExecutionHash.high,
      txHashes
    );
  });
});
