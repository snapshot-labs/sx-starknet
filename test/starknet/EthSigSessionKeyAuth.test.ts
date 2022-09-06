import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import {
  Account as StarknetAccount,
  ec,
  defaultProvider,
  typedData,
  hash,
  KeyPair,
  Signer,
} from 'starknet';
import { ethers } from 'hardhat';
import { domain, SessionKey, sessionKeyTypes } from '../shared/types';
import { proposeTypes, voteTypes } from '../shared/starkTypes';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { utils } from '@snapshot-labs/sx';
import { ethereumSigSessionKeyAuthSetup } from '../shared/setup';
import { ECDH } from 'crypto';
import { getMessageHash } from 'starknet/dist/utils/typedData';

function createAccount(): StarknetAccount {
  let starkKeyPair = ec.genKeyPair();
  const privKey = starkKeyPair.getPrivate('hex');
  starkKeyPair = ec.getKeyPair(`0x${privKey}`);
  const address = ec.getStarkKey(starkKeyPair);
  const account = new StarknetAccount(defaultProvider, address, starkKeyPair);
  return account;
}

describe('Ethereum Signature Session Key Auth testing', () => {
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
  let proposerEthAddress: string;
  let proposeCalldata: string[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let usedVotingStrategiesHash2: string;
  let userVotingParamsAll2: string[][];
  let userVotingStrategyParamsFlatHash2: string;
  let voteCalldata: string[];

  // Session Key
  let sessionSigner: Signer;
  let sessionPublicKey: string;
  let sessionDuration: string;

  before(async function () {
    this.timeout(800000);
    const accounts = await ethers.getSigners();

    sessionSigner = new Signer(ec.genKeyPair());
    sessionPublicKey = await sessionSigner.getPubKey();

    ({ space, controller, ethSigSessionKeyAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await ethereumSigSessionKeyAuthSetup());

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

    proposerEthAddress = accounts[0].address;
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerEthAddress,
      metadataUriInts,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = accounts[0].address;
    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [[]];
    usedVotingStrategiesHash2 = hash.computeHashOnElements(usedVotingStrategies2);
    const userVotingStrategyParamsFlat2 = utils.encoding.flatten2DArray(userVotingParamsAll2);
    userVotingStrategyParamsFlatHash2 = hash.computeHashOnElements(userVotingStrategyParamsFlat2);
    voteCalldata = utils.encoding.getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Should generate a session key if a valid signature is provided', async () => {
    // -- Authenticates the session key --
    {
      const accounts = await ethers.getSigners();
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex('0x01');
      sessionDuration = '0xfffff';
      const message: SessionKey = {
        address: utils.encoding.hexPadRight(accounts[0].address),
        sessionPublicKey: utils.encoding.hexPadRight(sessionPublicKey),
        sessionDuration: utils.encoding.hexPadRight(sessionDuration),
        salt: salt.toHex(),
      };
      const sig = await accounts[0]._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_from_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: accounts[0].address,
        session_public_key: sessionPublicKey,
        session_duration: sessionDuration,
      });
      const { eth_address } = await ethSigSessionKeyAuth.call('get_session_key_owner', {
        session_public_key: sessionPublicKey,
      });
      expect(eth_address).to.deep.equal(BigInt(accounts[0].address));
    }

    // -- Creates the proposal --
    {
      const proposalSalt = '0x01';

      const message = {
        authenticator: ethSigSessionKeyAuth.address,
        space: spaceAddress,
        proposerAddress: proposerEthAddress,
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
        expect(err.message).to.contain('Salt already used');
      }
    }

    // -- Casts Vote --
    {
      console.log('Casting a vote FOR...');
      const voteSalt = '0x02';

      const message = {
        authenticator: ethSigSessionKeyAuth.address,
        space: spaceAddress,
        voterAddress: voterEthAddress,
        proposal: proposalId,
        choice: utils.choice.Choice.FOR,
        usedVotingStrategiesHash: usedVotingStrategiesHash2,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash2,
        salt: voteSalt,
      };
      const msg = { types: voteTypes, primaryType: 'Vote', domain, message };
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
        expect(err.message).to.contain('Salt already used');
      }
    }
  }).timeout(6000000);
});
