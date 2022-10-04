import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import { ec, typedData, hash, Signer } from 'starknet';
import { ethers, starknet } from 'hardhat';
import {
  domain,
  SessionKey,
  sessionKeyTypes,
  RevokeSessionKey,
  revokeSessionKeyTypes,
} from '../shared/types';
import * as starkTypes from '../shared/starkTypes';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { utils } from '@snapshot-labs/sx';
import { ethSigSessionKeyAuthSetup } from '../shared/setup';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

function sleep(milliseconds: number) {
  const date = Date.now();
  let currentDate = null;
  do {
    currentDate = Date.now();
  } while (currentDate - date < milliseconds);
}

describe('Ethereum Signature Session Key Auth testing', () => {
  let account: SignerWithAddress;
  let account2: SignerWithAddress;

  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let ethSigSessionKeyAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: string;
  let executionHash: string;
  let metadataUri: string;
  let metadataUriInts: utils.intsSequence.IntsSequence;
  let usedVotingStrategies1: string[];
  let usedVotingStrategiesHash1: string;
  let userVotingParamsAll1: string[][];
  let userVotingStrategyParamsFlatHash1: string;
  let executionStrategy: string;
  let executionParams: string[];
  let proposeCalldata: string[];

  // Additional parameters for voting
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let usedVotingStrategiesHash2: string;
  let userVotingParamsAll2: string[][];
  let userVotingStrategyParamsFlatHash2: string;
  let voteCalldata: string[];

  // Session Keys
  let sessionSigner: Signer;
  let sessionPublicKey: string;
  let sessionDuration: string;
  let sessionSigner2: Signer;
  let sessionPublicKey2: string;

  before(async function () {
    this.timeout(800000);

    const accounts = await ethers.getSigners();
    account = accounts[0];
    account2 = accounts[1];

    sessionSigner = new Signer(ec.genKeyPair());
    sessionPublicKey = await sessionSigner.getPubKey();
    sessionSigner2 = new Signer(ec.genKeyPair());
    sessionPublicKey2 = await sessionSigner2.getPubKey();

    ({ space, controller, ethSigSessionKeyAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await ethSigSessionKeyAuthSetup());

    metadataUri = 'Hello and welcome to Snapshot X. This is the future of governance.';
    metadataUriInts = utils.intsSequence.IntsSequence.LEFromString(metadataUri);
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy = vanillaExecutionStrategy.address;
    spaceAddress = space.address;

    executionParams = ['0x01']; // Random params
    executionHash = hash.computeHashOnElements(executionParams);
    usedVotingStrategiesHash1 = hash.computeHashOnElements(usedVotingStrategies1);
    const userVotingStrategyParamsFlat1 = utils.encoding.flatten2DArray(userVotingParamsAll1);
    userVotingStrategyParamsFlatHash1 = hash.computeHashOnElements(userVotingStrategyParamsFlat1);

    proposeCalldata = utils.encoding.getProposeCalldata(
      account.address,
      metadataUriInts,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [[]];
    usedVotingStrategiesHash2 = hash.computeHashOnElements(usedVotingStrategies2);
    const userVotingStrategyParamsFlat2 = utils.encoding.flatten2DArray(userVotingParamsAll2);
    userVotingStrategyParamsFlatHash2 = hash.computeHashOnElements(userVotingStrategyParamsFlat2);
    voteCalldata = utils.encoding.getVoteCalldata(
      account.address,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Should not generate a session key if an invalid signature is provided', async () => {
    try {
      const accounts = await ethers.getSigners();
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex(
        ethers.utils.hexlify(ethers.utils.randomBytes(4))
      );
      sessionDuration = '0x30';
      const message: SessionKey = {
        address: accounts[0].address,
        sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey),
        sessionDuration: sessionDuration,
        salt: salt.toHex(),
      };
      const sig = await account._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      // Different session duration to signed data
      await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_with_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: '0x1111',
      });
      throw { message: '' };
    } catch (err: any) {
      expect(err.message).to.contain('Invalid signature.');
    }
  }).timeout(6000000);

  it('Should generate a session key and allow authentication via it if a valid signature is provided', async () => {
    // -- Authenticates the session key --
    {
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex(
        ethers.utils.hexlify(ethers.utils.randomBytes(4))
      );
      sessionDuration = '0xffff';
      const message: SessionKey = {
        address: account.address,
        sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey),
        sessionDuration: sessionDuration,
        salt: salt.toHex(),
      };
      const sig = await account._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_with_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
      const { eth_address } = await ethSigSessionKeyAuth.call('get_session_key_owner', {
        session_public_key: sessionPublicKey,
      });
      expect(eth_address).to.deep.equal(BigInt(account.address));
    }

    // -- Creates the proposal --
    {
      const proposalSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        space: spaceAddress,
        author: account.address,
        metadata_uri: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        execution_hash: executionHash,
        strategies_hash: usedVotingStrategiesHash1,
        strategies_params_hash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: starkTypes.proposeTypes,
        primaryType: 'Propose',
        domain: starkTypes.domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      console.log('Creating proposal...');
      await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
        r: r,
        s: s,
        salt: proposalSalt,
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
        session_public_key: sessionPublicKey,
      });

      // -- Attempts a replay attack on `propose` method --
      // Expected to fail
      try {
        console.log('Replaying transaction...');
        await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
          r: r,
          s: s,
          salt: proposalSalt,
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
          session_public_key: sessionPublicKey,
        });
        throw { message: 'replay attack worked on `propose`' };
      } catch (err: any) {
        expect(err.message).to.contain('StarkEIP191: Salt already used');
      }
    }

    // -- Casts Vote --
    {
      console.log('Casting a vote FOR...');
      const voteSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        space: spaceAddress,
        voter: account.address,
        proposal: proposalId,
        choice: utils.choice.Choice.FOR,
        strategies_hash: usedVotingStrategiesHash2,
        strategies_params_hash: userVotingStrategyParamsFlatHash2,
        salt: voteSalt,
      };
      const msg = {
        types: starkTypes.voteTypes,
        primaryType: 'Vote',
        domain: starkTypes.domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
        r: r,
        s: s,
        salt: voteSalt,
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
        session_public_key: sessionPublicKey,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = utils.splitUint256.SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));

      // -- Attempts a replay attack on `vote` method --
      try {
        console.log('Replaying vote...');
        await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
          r: r,
          s: s,
          salt: voteSalt,
          target: spaceAddress,
          function_selector: VOTE_SELECTOR,
          calldata: voteCalldata,
          session_public_key: sessionPublicKey,
        });
        throw { message: 'replay attack worked on `vote`' };
      } catch (err: any) {
        expect(err.message).to.contain('StarkEIP191: Salt already used');
      }
    }
  }).timeout(6000000);

  it('Should reject an invalid session key', async () => {
    try {
      // Invalid session key
      const sessionSigner2 = new Signer(ec.genKeyPair());
      const sessionPublicKey2 = await sessionSigner2.getPubKey();
      const voteSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));
      const message = {
        authenticator: ethSigSessionKeyAuth.address,
        space: spaceAddress,
        voter: account.address,
        proposal: proposalId,
        choice: utils.choice.Choice.FOR,
        strategies_hash: usedVotingStrategiesHash2,
        strategies_params_hash: userVotingStrategyParamsFlatHash2,
        salt: voteSalt,
      };
      const msg = { types: starkTypes.voteTypes, primaryType: 'Vote', domain, message };
      const sig = await sessionSigner2.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
        r: r,
        s: s,
        salt: voteSalt,
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
        session_public_key: sessionPublicKey2,
      });
      throw { message: '' };
    } catch (err: any) {
      expect(err.message).to.contain('SessionKey: Session does not exist');
    }
  }).timeout(6000000);

  it('Should reject an expired session key', async () => {
    // -- Authenticates the session key --
    {
      const accounts = await ethers.getSigners();
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex(
        ethers.utils.hexlify(ethers.utils.randomBytes(4))
      );
      sessionDuration = '0x1'; // 1 second duration session
      const message: SessionKey = {
        address: accounts[1].address,
        sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey2),
        sessionDuration: sessionDuration,
        salt: salt.toHex(),
      };
      const sig = await account2._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_with_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: account2.address,
        session_public_key: sessionPublicKey2,
        session_duration: sessionDuration,
      });
    }

    // -- Creates the proposal --
    {
      const proposalSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        authenticator: ethSigSessionKeyAuth.address,
        space: spaceAddress,
        author: account2.address,
        metadata_uri: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        execution_hash: executionHash,
        strategies_hash: usedVotingStrategiesHash1,
        strategies_params_hash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: starkTypes.proposeTypes,
        primaryType: 'Propose',
        domain: starkTypes.domain,
        message,
      };
      const sig = await sessionSigner2.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      try {
        await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
          r: r,
          s: s,
          salt: proposalSalt,
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
          session_public_key: sessionPublicKey2,
        });
        throw { message: '' };
      } catch (err: any) {
        expect(err.message).to.contain('SessionKey: Session has ended');
      }
    }
  }).timeout(6000000);

  it('Should allow revoking of a session key via a signature from the session key', async () => {
    // -- Revokes Session Key --
    {
      const salt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        salt: salt,
      };
      const msg: typedData.TypedData = {
        types: starkTypes.revokeSessionKeyTypes,
        primaryType: 'RevokeSessionKey',
        domain: starkTypes.domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      await controller.invoke(ethSigSessionKeyAuth, 'revoke_session_key_with_session_key_sig', {
        r: r,
        s: s,
        salt: salt,
        session_public_key: sessionPublicKey,
      });
    }

    // -- Checks that the session key can no longer be used
    {
      const proposalSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        space: spaceAddress,
        author: account.address,
        metadata_uri: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        execution_hash: executionHash,
        strategies_hash: usedVotingStrategiesHash1,
        strategies_params_hash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: starkTypes.proposeTypes,
        primaryType: 'Propose',
        domain: starkTypes.domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      try {
        console.log('Creating proposal...');
        await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
          r: r,
          s: s,
          salt: proposalSalt,
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
          session_public_key: sessionPublicKey,
        });
        throw { message: '' };
      } catch (err: any) {
        expect(err.message).to.contain('SessionKey: Session does not exist');
      }
    }
  }).timeout(6000000);

  it('Should allow revoking of a session key via a signature from the owners ethereum key', async () => {
    // -- Authenticates the session key --
    {
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex(
        ethers.utils.hexlify(ethers.utils.randomBytes(4))
      );
      sessionDuration = '0xffff';
      const message: SessionKey = {
        address: account.address,
        sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey),
        sessionDuration: sessionDuration,
        salt: salt.toHex(),
      };
      const sig = await account._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_with_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
    }

    // -- Revokes Session Key --
    {
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex(
        ethers.utils.hexlify(ethers.utils.randomBytes(4))
      );

      const message: RevokeSessionKey = {
        sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey),
        salt: salt.toHex(),
      };
      const sig = await account._signTypedData(domain, revokeSessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);

      await controller.invoke(ethSigSessionKeyAuth, 'revoke_session_key_with_owner_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        session_public_key: sessionPublicKey,
      });
    }

    // -- Checks that the session key can no longer be used
    {
      const proposalSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        space: spaceAddress,
        author: account.address,
        metadata_uri: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        execution_hash: executionHash,
        strategies_hash: usedVotingStrategiesHash1,
        strategies_params_hash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: starkTypes.proposeTypes,
        primaryType: 'Propose',
        domain: starkTypes.domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethSigSessionKeyAuth.address);
      const [r, s] = sig;

      try {
        console.log('Creating proposal...');
        await controller.invoke(ethSigSessionKeyAuth, 'authenticate', {
          r: r,
          s: s,
          salt: proposalSalt,
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
          session_public_key: sessionPublicKey,
        });
        throw { message: '' };
      } catch (err: any) {
        expect(err.message).to.contain('SessionKey: Session does not exist');
      }
    }
  }).timeout(6000000);

  it('Should fail if overflow occurs when calculating the session end timestamp session duration', async () => {
    const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex(
      ethers.utils.hexlify(ethers.utils.randomBytes(4))
    );
    sessionDuration = '0xfffffffffffffffffffffffffffffffffffffffffffffff'; // Greater than RANGE_CHECK_BOUND
    const message: SessionKey = {
      address: account.address,
      sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey),
      sessionDuration: sessionDuration,
      salt: salt.toHex(),
    };
    const sig = await account._signTypedData(domain, sessionKeyTypes, message);
    const { r, s, v } = utils.encoding.getRSVFromSig(sig);

    try {
      await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_with_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
      throw { message: '' };
    } catch (err: any) {
      expect(err.message).to.contain('SessionKey: Invalid session duration');
    }
  }).timeout(6000000);
});
