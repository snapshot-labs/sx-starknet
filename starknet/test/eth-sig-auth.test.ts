import { expect } from 'chai';
import dotenv from 'dotenv';
import { ethers } from 'ethers';
import { starknet } from 'hardhat';
import { CallData, cairo, shortString } from 'starknet';
import {
  Propose,
  proposeTypes,
  voteTypes,
  Vote,
  updateProposalTypes,
  UpdateProposal,
} from './eth-sig-types';
import { getRSVFromSig } from './utils';

dotenv.config();

const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';
describe('Ethereum Signature Authenticator', function () {
  this.timeout(1000000);

  const domain = {
    chainId: '0x534e5f474f45524c49', // devnet id
  };

  let signer: ethers.HDNodeWallet;

  let account: starknet.starknetAccount;
  let ethSigAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;

  before(async function () {
    signer = ethers.Wallet.createRandom();

    account = await starknet.OpenZeppelinAccount.getAccountFromAddress(account_address, account_pk);

    const ethSigAuthenticatorFactory = await starknet.getContractFactory('sx_EthSigAuthenticator');
    const vanillaVotingStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaVotingStrategy',
    );
    const vanillaProposalValidationStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaProposalValidationStrategy',
    );
    const spaceFactory = await starknet.getContractFactory('sx_Space');

    try {
      // If the contracts are already declared, this will be skipped
      await account.declare(ethSigAuthenticatorFactory);
      await account.declare(vanillaVotingStrategyFactory);
      await account.declare(vanillaProposalValidationStrategyFactory);
      await account.declare(spaceFactory);
    } catch {}

    ethSigAuthenticator = await account.deploy(ethSigAuthenticatorFactory);
    vanillaVotingStrategy = await account.deploy(vanillaVotingStrategyFactory);
    vanillaProposalValidationStrategy = await account.deploy(
      vanillaProposalValidationStrategyFactory,
    );
    space = await account.deploy(spaceFactory);

    // Initializing the space
    const initializeCalldata = CallData.compile({
      _owner: 1,
      _max_voting_duration: 20,
      _min_voting_duration: 20,
      _voting_delay: 10,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategy.address,
        params: [],
      },
      _proposal_validation_strategy_metadata_URI: [],
      _voting_strategies: [{ address: vanillaVotingStrategy.address, params: [] }],
      _voting_strategies_metadata_URI: [],
      _authenticators: [ethSigAuthenticator.address],
      _metadata_URI: [],
      _dao_URI: [],
    });

    await account.invoke(space, 'initialize', initializeCalldata, { rawInput: true });

    // Dumping the Starknet state so it can be loaded at the same point for each test
    await starknet.devnet.dump('dump.pkl');
  }, 10000000);

  it('can authenticate a proposal, a vote, and a proposal update', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      userProposalValidationParams: [
        '0xffffffffffffffffffffffffffffffffffffffffff',
        '0x1234',
        '0x5678',
        '0x9abc',
      ],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x0',
    };

    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    const proposeCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: proposeMsg.space,
      author: proposeMsg.author,
      executionStrategy: proposeMsg.executionStrategy,
      userProposalValidationParams: proposeMsg.userProposalValidationParams,
      metadataUri: proposeMsg.metadataUri,
      salt: cairo.uint256(proposeMsg.salt),
    });

    await account.invoke(ethSigAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      proposalId: '0x1',
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    sig = await signer.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    splitSig = getRSVFromSig(sig);

    const updateProposalCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: updateProposalMsg.space,
      author: updateProposalMsg.author,
      proposalId: cairo.uint256(updateProposalMsg.proposalId),
      executionStrategy: updateProposalMsg.executionStrategy,
      metadataUri: updateProposalMsg.metadataUri,
      salt: cairo.uint256(updateProposalMsg.salt),
    });

    await account.invoke(
      ethSigAuthenticator,
      'authenticate_update_proposal',
      updateProposalCalldata,
      { rawInput: true },
    );

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(10);

    // VOTE

    const voteMsg: Vote = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      voter: signer.address,
      proposalId: '0x1',
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    sig = await signer.signTypedData(domain, voteTypes, voteMsg);
    splitSig = getRSVFromSig(sig);

    const voteCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: voteMsg.space,
      voter: voteMsg.voter,
      proposalId: cairo.uint256(voteMsg.proposalId),
      choice: voteMsg.choice,
      userVotingStrategies: voteMsg.userVotingStrategies,
      metadataUri: voteMsg.metadataUri,
    });

    await account.invoke(ethSigAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);

  it('should revert if an incorrect signature is used', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      userProposalValidationParams: [
        '0xffffffffffffffffffffffffffffffffffffffffff',
        '0x1234',
        '0x5678',
        '0x9abc',
      ],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x0',
    };

    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    const proposeCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: proposeMsg.space,
      author: proposeMsg.author,
      executionStrategy: proposeMsg.executionStrategy,
      userProposalValidationParams: proposeMsg.userProposalValidationParams,
      metadataUri: proposeMsg.metadataUri,
      salt: cairo.uint256(proposeMsg.salt),
    });

    // Random, signer that does not correspond to the proposal author
    let invalidSigner = ethers.Wallet.createRandom();
    let invalidSig = await invalidSigner.signTypedData(domain, proposeTypes, proposeMsg);
    let invalidSplitSig = getRSVFromSig(invalidSig);

    const invalidProposeCalldata = CallData.compile({
      r: cairo.uint256(invalidSplitSig.r),
      s: cairo.uint256(invalidSplitSig.s),
      v: invalidSplitSig.v,
      space: proposeMsg.space,
      author: proposeMsg.author,
      executionStrategy: proposeMsg.executionStrategy,
      userProposalValidationParams: proposeMsg.userProposalValidationParams,
      metadataUri: proposeMsg.metadataUri,
      salt: cairo.uint256(proposeMsg.salt),
    });

    try {
      await account.invoke(ethSigAuthenticator, 'authenticate_propose', invalidProposeCalldata, {
        rawInput: true,
      });
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid signature'));
    }

    await account.invoke(ethSigAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      proposalId: '0x1',
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    sig = await signer.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    splitSig = getRSVFromSig(sig);

    const updateProposalCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: updateProposalMsg.space,
      author: updateProposalMsg.author,
      proposalId: cairo.uint256(updateProposalMsg.proposalId),
      executionStrategy: updateProposalMsg.executionStrategy,
      metadataUri: updateProposalMsg.metadataUri,
      salt: cairo.uint256(updateProposalMsg.salt),
    });

    // Random, signer that does not correspond to the proposal author
    invalidSigner = ethers.Wallet.createRandom();
    invalidSig = await invalidSigner.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    invalidSplitSig = getRSVFromSig(invalidSig);

    const invalidUpdateProposalCalldata = CallData.compile({
      r: cairo.uint256(invalidSplitSig.r),
      s: cairo.uint256(invalidSplitSig.s),
      v: invalidSplitSig.v,
      space: updateProposalMsg.space,
      author: updateProposalMsg.author,
      proposalId: cairo.uint256(updateProposalMsg.proposalId),
      executionStrategy: updateProposalMsg.executionStrategy,
      metadataUri: updateProposalMsg.metadataUri,
      salt: cairo.uint256(updateProposalMsg.salt),
    });

    try {
      await account.invoke(
        ethSigAuthenticator,
        'authenticate_update_proposal',
        invalidUpdateProposalCalldata,
        {
          rawInput: true,
        },
      );
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid signature'));
    }

    await account.invoke(
      ethSigAuthenticator,
      'authenticate_update_proposal',
      updateProposalCalldata,
      { rawInput: true },
    );

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(10);

    // VOTE

    const voteMsg: Vote = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      voter: signer.address,
      proposalId: '0x1',
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    sig = await signer.signTypedData(domain, voteTypes, voteMsg);
    splitSig = getRSVFromSig(sig);

    const voteCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: voteMsg.space,
      voter: voteMsg.voter,
      proposalId: cairo.uint256(voteMsg.proposalId),
      choice: voteMsg.choice,
      userVotingStrategies: voteMsg.userVotingStrategies,
      metadataUri: voteMsg.metadataUri,
    });

    // Random, signer that does not correspond to the voter
    invalidSigner = ethers.Wallet.createRandom();
    invalidSig = await invalidSigner.signTypedData(domain, voteTypes, voteMsg);
    invalidSplitSig = getRSVFromSig(invalidSig);

    const invalidVoteCalldata = CallData.compile({
      r: cairo.uint256(invalidSplitSig.r),
      s: cairo.uint256(invalidSplitSig.s),
      v: invalidSplitSig.v,
      space: voteMsg.space,
      voter: voteMsg.voter,
      proposalId: cairo.uint256(voteMsg.proposalId),
      choice: voteMsg.choice,
      userVotingStrategies: voteMsg.userVotingStrategies,
      metadataUri: voteMsg.metadataUri,
    });

    try {
      await account.invoke(ethSigAuthenticator, 'authenticate_vote', invalidVoteCalldata, {
        rawInput: true,
      });
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid signature'));
    }

    await account.invoke(ethSigAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);

  it('should revert if a salt is reused by an author when creating or updating a proposal', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      userProposalValidationParams: [
        '0xffffffffffffffffffffffffffffffffffffffffff',
        '0x1234',
        '0x5678',
        '0x9abc',
      ],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x0',
    };

    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    const proposeCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: proposeMsg.space,
      author: proposeMsg.author,
      executionStrategy: proposeMsg.executionStrategy,
      userProposalValidationParams: proposeMsg.userProposalValidationParams,
      metadataUri: proposeMsg.metadataUri,
      salt: cairo.uint256(proposeMsg.salt),
    });

    await account.invoke(ethSigAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });

    try {
      await account.invoke(ethSigAuthenticator, 'authenticate_propose', proposeCalldata, {
        rawInput: true,
      });
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
    }

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      proposalId: '0x1',
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x1',
    };

    sig = await signer.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    splitSig = getRSVFromSig(sig);

    const updateProposalCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: updateProposalMsg.space,
      author: updateProposalMsg.author,
      proposalId: cairo.uint256(updateProposalMsg.proposalId),
      executionStrategy: updateProposalMsg.executionStrategy,
      metadataUri: updateProposalMsg.metadataUri,
      salt: cairo.uint256(updateProposalMsg.salt),
    });

    await account.invoke(
      ethSigAuthenticator,
      'authenticate_update_proposal',
      updateProposalCalldata,
      { rawInput: true },
    );

    try {
      await account.invoke(
        ethSigAuthenticator,
        'authenticate_update_proposal',
        updateProposalCalldata,
        { rawInput: true },
      );
    } catch (err: any) {
      // 'salt already used' error
      expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
    }

    // Increase time so voting period begins
    await starknet.devnet.increaseTime(10);

    // VOTE

    const voteMsg: Vote = {
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      voter: signer.address,
      proposalId: '0x1',
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    sig = await signer.signTypedData(domain, voteTypes, voteMsg);
    splitSig = getRSVFromSig(sig);

    const voteCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: voteMsg.space,
      voter: voteMsg.voter,
      proposalId: cairo.uint256(voteMsg.proposalId),
      choice: voteMsg.choice,
      userVotingStrategies: voteMsg.userVotingStrategies,
      metadataUri: voteMsg.metadataUri,
    });

    await account.invoke(ethSigAuthenticator, 'authenticate_vote', voteCalldata, {
      rawInput: true,
    });
  }, 1000000);
});
