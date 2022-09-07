import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { ec, typedData, hash, Signer } from 'starknet';
import { StarknetContract, Account, HttpNetworkConfig } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { ethTxSessionKeyAuthSetup } from '../shared/setup';
import { domain, SessionKey, sessionKeyTypes } from '../shared/types';

import { proposeTypes, voteTypes } from '../shared/starkTypes';
import { PROPOSE_SELECTOR } from '../shared/constants';

const { computeHashOnElements } = hash;

function getCommit(ethAddress: string, sessionPublicKey: string, sessionDuration: string): string {
  return computeHashOnElements([ethAddress, sessionPublicKey, sessionDuration]);
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
  let ethAddress: string;
  let proposeCalldata: string[];

  // Session Key
  let sessionSigner: Signer;
  let sessionPublicKey: string;
  let sessionDuration: string;

  before(async function () {
    const accounts = await ethers.getSigners();
    account = accounts[0];
    account2 = accounts[1];
    ethAddress = account.address;

    sessionSigner = new Signer(ec.genKeyPair());
    sessionPublicKey = await sessionSigner.getPubKey();
    sessionDuration = '0x1111';

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

    ethAddress = accounts[0].address;
    proposeCalldata = utils.encoding.getProposeCalldata(
      ethAddress,
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
        getCommit(ethAddress, sessionPublicKey, sessionDuration)
      );
    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
    await ethTxSessionKeyAuth.invoke('authorize_session_key_from_tx', {
      eth_address: ethAddress,
      session_public_key: sessionPublicKey,
      session_duration: sessionDuration,
    });
    const { eth_address } = await ethTxSessionKeyAuth.call('get_session_key_owner', {
      session_public_key: sessionPublicKey,
    });
    expect(eth_address).to.deep.equal(BigInt(ethAddress));

    // -- Creates the proposal --
    {
      const proposalSalt = '0x08';

      const message = {
        authenticator: ethTxSessionKeyAuth.address,
        space: spaceAddress,
        proposerAddress: ethAddress,
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
        getCommit(ethAddress, sessionPublicKey, sessionDuration)
      );
    await starknet.devnet.flush();
    try {
      await ethTxSessionKeyAuth.invoke('authorize_session_key_from_tx', {
        eth_address: ethAddress,
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
        getCommit(ethAddress, sessionPublicKey, sessionDuration)
      );
    await starknet.devnet.flush();
    try {
      await ethTxSessionKeyAuth.invoke('authorize_session_key_from_tx', {
        eth_address: ethAddress,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
    } catch (err: any) {
      expect(err.message).to.contain('Commit made by invalid L1 address');
    }
  });
});
