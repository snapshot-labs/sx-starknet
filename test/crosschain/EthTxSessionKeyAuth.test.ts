import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { ec, typedData, hash, Signer } from 'starknet';
import { StarknetContract, Account, HttpNetworkConfig } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { ethTxSessionKeyAuthSetup } from '../shared/setup';
import { domain } from '../shared/types';

import { proposeTypes, revokeSessionKeyTypes } from '../shared/starkTypes';
import { PROPOSE_SELECTOR } from '../shared/constants';

const { computeHashOnElements } = hash;

function getSessionKeyCommit(
  ethAddress: string,
  sessionPublicKey: string,
  sessionDuration: string
): string {
  return computeHashOnElements([ethAddress, sessionPublicKey, sessionDuration]);
}

function getRevokeSessionKeyCommit(ethAddress: string, sessionPublicKey: string): string {
  return computeHashOnElements([ethAddress, sessionPublicKey]);
}

describe('Ethereum Transaction Session Keys', function () {
  this.timeout(5000000);
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let account: SignerWithAddress;
  let account2: SignerWithAddress;

  // Contracts
  let mockStarknetMessaging: Contract;
  let space: StarknetContract;
  let ethTxSessionKeyAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let starknetCommit: Contract;
  let controller: Account;

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

  // Session Keys
  let sessionSigner: Signer;
  let sessionPublicKey: string;
  let sessionDuration: string;
  let sessionSigner2: Signer;
  let sessionPublicKey2: string;

  before(async function () {
    const accounts = await ethers.getSigners();
    account = accounts[0];
    account2 = accounts[1];

    sessionSigner = new Signer(ec.genKeyPair());
    sessionPublicKey = await sessionSigner.getPubKey();
    sessionDuration = '0x1111';

    sessionSigner2 = new Signer(ec.genKeyPair());
    sessionPublicKey2 = await sessionSigner2.getPubKey();

    ({
      space,
      controller,
      ethTxSessionKeyAuth,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
      mockStarknetMessaging,
      starknetCommit,
    } = await ethTxSessionKeyAuthSetup());

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
  });

  it('should authorize a session key from an L1 transaction and allow authentication via it', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    // Committing the hash of the payload to the StarkNet Commit L1 contract
    await starknetCommit
      .connect(account)
      .commit(
        ethTxSessionKeyAuth.address,
        getSessionKeyCommit(account.address, sessionPublicKey, sessionDuration)
      );
    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
    await ethTxSessionKeyAuth.invoke('authorize_session_key_with_tx', {
      eth_address: account.address,
      session_public_key: sessionPublicKey,
      session_duration: sessionDuration,
    });
    const { eth_address } = await ethTxSessionKeyAuth.call('get_session_key_owner', {
      session_public_key: sessionPublicKey,
    });
    expect(eth_address).to.deep.equal(BigInt(account.address));

    // -- Creates the proposal --
    {
      const proposalSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        space: spaceAddress,
        proposerAddress: account.address,
        metadataURI: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        executionParamsHash: executionHash,
        usedVotingStrategiesHash: usedVotingStrategiesHash1,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: proposeTypes,
        primaryType: 'Propose',
        domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethTxSessionKeyAuth.address);
      const [r, s] = sig;

      console.log('Creating proposal...');
      await controller.invoke(ethTxSessionKeyAuth, 'authenticate', {
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
        await controller.invoke(ethTxSessionKeyAuth, 'authenticate', {
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
        expect(err.message).to.contain('Salt already used');
      }
    }
  });

  it('Authorization should fail if the correct hash of the payload is not committed on l1 before execution is called', async () => {
    const fakeSessionDuration = '0xffff';
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    await starknetCommit
      .connect(account)
      .commit(
        ethTxSessionKeyAuth.address,
        getSessionKeyCommit(account.address, sessionPublicKey, sessionDuration)
      );
    await starknet.devnet.flush();
    try {
      await ethTxSessionKeyAuth.invoke('authorize_session_key_with_tx', {
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: fakeSessionDuration,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Hash not yet committed or already executed');
    }
  });

  it('Authorization should fail if the commit sender address is not equal to the address in the payload', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    await starknetCommit
      .connect(account2)
      .commit(
        ethTxSessionKeyAuth.address,
        getSessionKeyCommit(account.address, sessionPublicKey, sessionDuration)
      );
    await starknet.devnet.flush();
    try {
      await ethTxSessionKeyAuth.invoke('authorize_session_key_with_tx', {
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Commit made by invalid L1 address');
    }
  });

  it('Should allow revoking of a session key via a signature from the session key', async () => {
    // -- Revokes Session Key --
    {
      const salt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        salt: salt,
      };
      const msg: typedData.TypedData = {
        types: revokeSessionKeyTypes,
        primaryType: 'RevokeSessionKey',
        domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethTxSessionKeyAuth.address);
      const [r, s] = sig;

      await controller.invoke(ethTxSessionKeyAuth, 'revoke_session_key_with_session_key_sig', {
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
        proposerAddress: account.address,
        metadataURI: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        executionParamsHash: executionHash,
        usedVotingStrategiesHash: usedVotingStrategiesHash1,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: proposeTypes,
        primaryType: 'Propose',
        domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethTxSessionKeyAuth.address);
      const [r, s] = sig;

      try {
        console.log('Creating proposal...');
        await controller.invoke(ethTxSessionKeyAuth, 'authenticate', {
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
        expect(err.message).to.contain('Session does not exist');
      }
    }
  }).timeout(6000000);

  it('Should allow revoking of a session key via a transaction from the owner Ethereum address', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    // -- Authenticates the session key --
    {
      // Committing the hash of the payload to the StarkNet Commit L1 contract
      await starknetCommit
        .connect(account)
        .commit(
          ethTxSessionKeyAuth.address,
          getSessionKeyCommit(account.address, sessionPublicKey, sessionDuration)
        );
      // Checking that the L1 -> L2 message has been propogated
      expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
      await ethTxSessionKeyAuth.invoke('authorize_session_key_with_tx', {
        eth_address: account.address,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
    }

    // -- Revokes Session Key --
    {
      // Committing the hash of the payload to the StarkNet Commit L1 contract
      await starknetCommit
        .connect(account)
        .commit(
          ethTxSessionKeyAuth.address,
          getRevokeSessionKeyCommit(account.address, sessionPublicKey)
        );
      await starknet.devnet.flush();
      await controller.invoke(ethTxSessionKeyAuth, 'revoke_session_key_with_owner_tx', {
        session_public_key: sessionPublicKey,
      });
    }

    // -- Checks that the session key can no longer be used
    {
      const proposalSalt = ethers.utils.hexlify(ethers.utils.randomBytes(4));

      const message = {
        space: spaceAddress,
        proposerAddress: account.address,
        metadataURI: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        executionParamsHash: executionHash,
        usedVotingStrategiesHash: usedVotingStrategiesHash1,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const msg: typedData.TypedData = {
        types: proposeTypes,
        primaryType: 'Propose',
        domain,
        message,
      };
      const sig = await sessionSigner.signMessage(msg, ethTxSessionKeyAuth.address);
      const [r, s] = sig;

      try {
        console.log('Creating proposal...');
        await controller.invoke(ethTxSessionKeyAuth, 'authenticate', {
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
        expect(err.message).to.contain('Session does not exist');
      }
    }
  }).timeout(6000000);
});
