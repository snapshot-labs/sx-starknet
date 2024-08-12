import { expect } from 'chai';
import dotenv from 'dotenv';
import { HDNodeWallet, Wallet } from 'ethers';
import { Account as StarknetAccount, Contract as StarknetContract, RpcProvider as StarknetRpcProvider, CallData, cairo, shortString, CairoCustomEnum } from 'starknet';
import { Devnet as StarknetDevnet } from 'starknet-devnet';
import {
  Propose,
  proposeTypes,
  voteTypes,
  Vote,
  updateProposalTypes,
  UpdateProposal,
} from './eth-sig-types';
import { getRSVFromSig, getCompiledCode } from './utils';

dotenv.config();

const chainId = '0x534e5f5345504f4c4941'; // SN_SEPOLIA
const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';
describe('Ethereum Signature Authenticator', function () {
  this.timeout(1000000);

  // EIP712 Domain is empty.
  const domain = {};

  let signer: HDNodeWallet;

  let account: StarknetAccount;
  let ethSigAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaProposalValidationStrategy: StarknetContract;
  let space: StarknetContract;
  let devnet: StarknetDevnet;
  let provider: StarknetRpcProvider;

  before(async function () {
    signer = Wallet.createRandom();

    console.log('account address:', account_address, 'account pk:', account_pk);

    const devnetConfig = {
      args: ["--seed", "42", "--lite-mode", "--dump-on", "exit", "--dump-path", "./dump.pkl"],
    };
    console.log("Spawning devnet...");
    devnet = await StarknetDevnet.spawnInstalled(devnetConfig); // TODO: should be a neew rather than spawninstalled

    provider = new StarknetRpcProvider({ nodeUrl: devnet.provider.url });

    // Account used for deployments
    account = new StarknetAccount(provider, account_address, account_pk);

    // Deploy the Stark Sig Authenticator
    console.log("Deploying Eth Sig Authenticator...");
    const { sierraCode: auth_sierra, casmCode: auth_casm } = await getCompiledCode('sx_EthSigAuthenticator');
    const auth_response = await account.declareAndDeploy({
      contract: auth_sierra,
      casm: auth_casm,
    });
    ethSigAuthenticator = new StarknetContract(auth_sierra.abi, auth_response.deploy.contract_address, provider);
    console.log("Stark Eth Authenticator: ", ethSigAuthenticator.address);

    // Deploy the Vanilla Voting strategy
    console.log("Deploying Voting Strategy...");
    const { sierraCode: voting_sierra, casmCode: voting_casm } = await getCompiledCode('sx_VanillaVotingStrategy');
    const voting_response = await account.declareAndDeploy({ contract: voting_sierra, casm: voting_casm });
    vanillaVotingStrategy = new StarknetContract(voting_sierra.abi, voting_response.deploy.contract_address, provider);
    console.log("Vanilla Voting Strategy: ", vanillaVotingStrategy.address);

    // Deploy the Vanilla Proposal Validation strategy
    console.log("Deploying Validation Strategy...");
    const { sierraCode: proposal_sierra, casmCode: proposal_casm } = await getCompiledCode('sx_VanillaProposalValidationStrategy');
    const proposal_response = await account.declareAndDeploy({ contract: proposal_sierra, casm: proposal_casm });
    vanillaProposalValidationStrategy = new StarknetContract(proposal_sierra.abi, proposal_response.deploy.contract_address, provider);
    console.log("Vanilla Proposal Validation Strategy: ", vanillaProposalValidationStrategy.address);

    // Deploy the Space
    console.log("Deploying Space...");
    const { sierraCode: space_sierra, casmCode: space_casm } = await getCompiledCode('sx_Space');
    const space_response = await account.declareAndDeploy({ contract: space_sierra, casm: space_casm });
    space = new StarknetContract(space_sierra.abi, space_response.deploy.contract_address, provider);
    console.log("Space: ", space.address);

    // Connect with our account
    space.connect(account);

    const _owner = 1;
    const _max_voting_duration = 200;
    const _min_voting_duration = 200;
    const _voting_delay = 100;
    const _proposal_validation_strategy = {
      address: vanillaProposalValidationStrategy.address,
      params: [],
    };
    const _proposal_validation_strategy_metadata_uri = [];
    const _voting_strategies = [{ address: vanillaVotingStrategy.address, params: [] }];
    const _voting_strategies_metadata_uri = [[]];
    const _authenticators = [ethSigAuthenticator.address];
    const _metadata_uri = [];
    const _dao_uri = [];

    console.log("Initializing space...");
    const initializeRes = await space.initialize(
      _owner,
      _max_voting_duration,
      _min_voting_duration,
      _voting_delay,
      _proposal_validation_strategy,
      _proposal_validation_strategy_metadata_uri,
      _voting_strategies,
      _voting_strategies_metadata_uri,
      _authenticators,
      _metadata_uri,
      _dao_uri);
    await provider.waitForTransaction(initializeRes.transaction_hash);
    console.log("Space initialized");

    // Dumping the Starknet state so it can be loaded at the same point for each test
    console.log("Dumping state...");
    await devnet.provider.dump('dump.pkl');
    console.log("State dumped");
  });

  it('can authenticate a proposal, a vote, and a proposal update', async () => {
    await devnet.provider.restart();
    await devnet.provider.load('./dump.pkl');
    await devnet.provider.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      chainId,
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
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
      salt: '0x0',
    };

    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    ethSigAuthenticator.connect(account);
    const r = cairo.uint256(splitSig.r);
    const s = cairo.uint256(splitSig.s);
    const v = splitSig.v;
    const salt = cairo.uint256(proposeMsg.salt);

    console.log("Authenticating proposal...");
    const proposeRes = await ethSigAuthenticator.authenticate_propose(r, s, v, proposeMsg.space, proposeMsg.author, proposeMsg.metadataUri, proposeMsg.executionStrategy, proposeMsg.userProposalValidationParams, salt);
    await provider.waitForTransaction(proposeRes.transaction_hash);
    console.log("Proposal authenticated");

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      chainId,
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

    const r1 = cairo.uint256(splitSig.r);
    const s1 = cairo.uint256(splitSig.s);
    const v1 = splitSig.v;
    const salt1 = cairo.uint256(updateProposalMsg.salt);

    console.log("Authenticating update proposal...");
    const updateProposalRes = await ethSigAuthenticator.authenticate_update_proposal(r1, s1, v1, updateProposalMsg.space, updateProposalMsg.author, updateProposalMsg.proposalId, updateProposalMsg.executionStrategy, updateProposalMsg.metadataUri, salt1);
    await provider.waitForTransaction(updateProposalRes.transaction_hash);
    console.log("Update proposal authenticated");

    // Increase time so voting period begins
    await devnet.provider.increaseTime(100);

    // VOTE

    const voteMsg: Vote = {
      chainId,
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

    const r2 = cairo.uint256(splitSig.r);
    const s2 = cairo.uint256(splitSig.s);
    const v2 = splitSig.v;

    console.log("Authenticating vote...");
    const choice = new CairoCustomEnum({ For: {} });
    const voteRes = await ethSigAuthenticator.authenticate_vote(r2, s2, v2, voteMsg.space, voteMsg.voter, voteMsg.proposalId, choice, voteMsg.userVotingStrategies, voteMsg.metadataUri);
    await provider.waitForTransaction(voteRes.transaction_hash);
    console.log("Vote authenticated");
  });

  it('should revert if an incorrect signature is used', async () => {
    await devnet.provider.restart();
    await devnet.provider.load('./dump.pkl');
    await devnet.provider.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      chainId,
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
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
      salt: '0x0',
    };

    // Random, signer that does not correspond to the proposal author
    let invalidSigner = Wallet.createRandom();

    try {
      let invalidSig = await invalidSigner.signTypedData(domain, proposeTypes, proposeMsg);
      let invalidSplitSig = getRSVFromSig(invalidSig);

      const invalidR = cairo.uint256(invalidSplitSig.r);
      const invalidS = cairo.uint256(invalidSplitSig.s);
      const invalidV = invalidSplitSig.v
      const salt = cairo.uint256(proposeMsg.salt);
      console.log("Submitting invalid proposal...");
      const invalidRes = await ethSigAuthenticator.authenticate_propose(invalidR, invalidS, invalidV, proposeMsg.space, proposeMsg.author, proposeMsg.metadataUri, proposeMsg.executionStrategy, proposeMsg.userProposalValidationParams, salt);
      await provider.waitForTransaction(invalidRes.transaction_hash);
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid signature'));
      console.log("Invalid proposal was correctly rejected");
    }

    // Now a correct proposal
    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    const r0 = cairo.uint256(splitSig.r);
    const s0 = cairo.uint256(splitSig.s);
    const v0 = splitSig.v;
    const salt = cairo.uint256(proposeMsg.salt);

    console.log("Authenticating proposal...");
    const proposeRes = await ethSigAuthenticator.authenticate_propose(r0, s0, v0, proposeMsg.space, proposeMsg.author, proposeMsg.metadataUri, proposeMsg.executionStrategy, proposeMsg.userProposalValidationParams, salt);
    await provider.waitForTransaction(proposeRes.transaction_hash);
    console.log("Proposal authenticated");

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      chainId,
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

    try {
      console.log("Invalid update proposal...")
      const invalidSig = await invalidSigner.signTypedData(domain, updateProposalTypes, updateProposalMsg);
      const invalidSplitSig = getRSVFromSig(invalidSig);
      const invalidR = cairo.uint256(invalidSplitSig.r);
      const invalidS = cairo.uint256(invalidSplitSig.s);
      const invalidV = invalidSplitSig.v;
      const salt = cairo.uint256(updateProposalMsg.salt);

      const invalidRes = await ethSigAuthenticator.authenticate_update_proposal(invalidR, invalidS, invalidV, updateProposalMsg.space, updateProposalMsg.author, updateProposalMsg.proposalId, updateProposalMsg.executionStrategy, updateProposalMsg.metadataUri, salt);
      await provider.waitForTransaction(invalidRes.transaction_hash);

      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid signature'));
      console.log("Invalid update proposal was correctly rejected");
    }

    // Now a correct update proposal
    console.log("Authenticating update proposal...");
    sig = await signer.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    splitSig = getRSVFromSig(sig);
    const r1 = cairo.uint256(splitSig.r);
    const s1 = cairo.uint256(splitSig.s);
    const v1 = splitSig.v;
    const salt1 = cairo.uint256(updateProposalMsg.salt);
    const updateRes = await ethSigAuthenticator.authenticate_update_proposal(r1, s1, v1, updateProposalMsg.space, updateProposalMsg.author, updateProposalMsg.proposalId, updateProposalMsg.executionStrategy, updateProposalMsg.metadataUri, salt1);
    await provider.waitForTransaction(updateRes.transaction_hash);
    console.log("Update proposal authenticated");

    // Increase time so voting period begins
    await devnet.provider.increaseTime(100);

    // VOTE

    const voteMsg: Vote = {
      chainId,
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      voter: signer.address,
      proposalId: '0x1',
      choice: '0x1',
      userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }],
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
    };

    try {
      const invalidSig = await invalidSigner.signTypedData(domain, voteTypes, voteMsg);
      const invalidSplitSig = getRSVFromSig(invalidSig);

      const invalidR = cairo.uint256(invalidSplitSig.r);
      const invalidS = cairo.uint256(invalidSplitSig.s);
      const invalidV = invalidSplitSig.v;

      console.log("Authenticating invalid vote...");
      const choice = new CairoCustomEnum({ For: {} });
      const invalidVoteRes = await ethSigAuthenticator.authenticate_vote(invalidR, invalidS, invalidV, voteMsg.space, voteMsg.voter, voteMsg.proposalId, choice, voteMsg.userVotingStrategies, voteMsg.metadataUri);
      await provider.waitForTransaction(invalidVoteRes.transaction_hash);
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Invalid signature'));
      console.log("Invalid vote was correctly rejected");
    }

    sig = await signer.signTypedData(domain, voteTypes, voteMsg);
    splitSig = getRSVFromSig(sig);

    const r2 = cairo.uint256(splitSig.r);
    const s2 = cairo.uint256(splitSig.s);
    const v2 = splitSig.v;

    console.log("Authenticating vote...");
    const choice = new CairoCustomEnum({ For: {} });
    const voteRes = await ethSigAuthenticator.authenticate_vote(r2, s2, v2, voteMsg.space, voteMsg.voter, voteMsg.proposalId, choice, voteMsg.userVotingStrategies, voteMsg.metadataUri);
    await provider.waitForTransaction(voteRes.transaction_hash);
    console.log("Vote authenticated");
  });

  it('should revert if a salt is reused by an author when creating or updating a proposal', async () => {
    await devnet.provider.restart();
    await devnet.provider.load('./dump.pkl');
    await devnet.provider.increaseTime(10);

    // PROPOSE
    const proposeMsg: Propose = {
      chainId,
      authenticator: ethSigAuthenticator.address,
      space: space.address,
      author: signer.address,
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
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
      metadataUri: proposeMsg.metadataUri,
      executionStrategy: proposeMsg.executionStrategy,
      userProposalValidationParams: proposeMsg.userProposalValidationParams,
      salt: cairo.uint256(proposeMsg.salt),
    });

    const r0 = cairo.uint256(splitSig.r);
    const s0 = cairo.uint256(splitSig.s);
    const v0 = splitSig.v;
    const salt0 = cairo.uint256(proposeMsg.salt);

    console.log("Authenticating proposal...");
    const proposeRes = await ethSigAuthenticator.authenticate_propose(r0, s0, v0, proposeMsg.space, proposeMsg.author, proposeMsg.metadataUri, proposeMsg.executionStrategy, proposeMsg.userProposalValidationParams, salt0);
    await provider.waitForTransaction(proposeRes.transaction_hash);
    console.log("Proposal authenticated");

    try {
      console.log("Attempting to reuse salt...");
      const invalidRes = await ethSigAuthenticator.authenticate_propose(r0, s0, v0, proposeMsg.space, proposeMsg.author, proposeMsg.metadataUri, proposeMsg.executionStrategy, proposeMsg.userProposalValidationParams, salt0);
      await provider.waitForTransaction(invalidRes.transaction);
      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
      console.log("Salt reuse was correctly rejected");
    }

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      chainId,
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

    const r1 = cairo.uint256(splitSig.r);
    const s1 = cairo.uint256(splitSig.s);
    const v1 = splitSig.v;
    const salt1 = cairo.uint256(updateProposalMsg.salt);

    console.log("Authenticating update proposal...");
    const updateProposalRes = await ethSigAuthenticator.authenticate_update_proposal(r1, s1, v1, updateProposalMsg.space, updateProposalMsg.author, updateProposalMsg.proposalId, updateProposalMsg.executionStrategy, updateProposalMsg.metadataUri, salt1);
    await provider.waitForTransaction(updateProposalRes.transaction_hash);
    console.log("Update proposal authenticated");


    try {
      console.log("Attempting to reuse salt...");
      const invalidRes = await ethSigAuthenticator.authenticate_update_proposal(r1, s1, v1, updateProposalMsg.space, updateProposalMsg.author, updateProposalMsg.proposalId, updateProposalMsg.executionStrategy, updateProposalMsg.metadataUri, salt1);
      await provider.waitForTransaction(invalidRes.transaction_hash);

      expect.fail('Should have failed');
    } catch (err: any) {
      expect(err.message).to.contain(shortString.encodeShortString('Salt Already Used'));
      console.log("Salt reuse was correctly rejected");
    }

    // Increase time so voting period begins
    await devnet.provider.increaseTime(100);
  });
});
