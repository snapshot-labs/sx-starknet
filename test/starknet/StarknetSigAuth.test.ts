import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import { Account as StarknetAccount, ec, defaultProvider, typedData } from 'starknet';
import { domain, proposeTypes, voteTypes } from '../shared/starkTypes';
import { computeHashOnElements, getSelectorFromName } from 'starknet/dist/utils/hash';
import { utils } from '@snapshot-labs/sx';
import { starknetSigAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';
import { _TypedDataEncoder } from 'ethers/lib/utils';
import { getStructHash, getTypeHash } from 'starknet/dist/utils/typedData';

export const AUTHENTICATE_METHOD = 'authenticate';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';

function createAccount() {
  let starkKeyPair = ec.genKeyPair();
  const privKey = starkKeyPair.getPrivate('hex');
  starkKeyPair = ec.getKeyPair(`0x${privKey}`);
  const pubKey = starkKeyPair.getPublic('hex');
  const address = ec.getStarkKey(starkKeyPair);
  const account = new StarknetAccount(defaultProvider, address, starkKeyPair);

  return { pubKey, address, account };
}

describe('Starknet Sig Auth testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let starkSigAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let user: any;

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
  let proposerAddress: string;
  let proposeCalldata: string[];

  // Session Key
  let sessionPublicKey: string;
  let sessionAccount: Account;

  // Additional parameters for voting
  let voterAddress: string;
  let proposalId: string;
  let choice: utils.choice.Choice;
  let usedVotingStrategies2: string[];
  let usedVotingStrategiesHash2: string;
  let userVotingParamsAll2: string[][];
  let userVotingStrategyParamsFlatHash2: string;
  let voteCalldata: string[];

  before(async function () {
    this.timeout(800000);
    ({ space, controller, starkSigAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await starknetSigAuthSetup());

    metadataUri = 'Hello and welcome to Snapshot X. This is the future of governance.';
    metadataUriInts = utils.intsSequence.IntsSequence.fromString(metadataUri);
    usedVotingStrategies1 = ['0x0'];
    userVotingParamsAll1 = [[]];
    executionStrategy = vanillaExecutionStrategy.address;
    spaceAddress = space.address;
    user = createAccount();

    executionParams = ['0x01']; // Random params
    executionHash = computeHashOnElements(executionParams);
    usedVotingStrategiesHash1 = computeHashOnElements(usedVotingStrategies1);
    const userVotingStrategyParamsFlat1 = utils.encoding.flatten2DArray(userVotingParamsAll1);
    userVotingStrategyParamsFlatHash1 = computeHashOnElements(userVotingStrategyParamsFlat1);

    proposerAddress = user.address;
    proposeCalldata = utils.encoding.getProposeCalldata(
      proposerAddress,
      metadataUriInts,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterAddress = user.address;
    proposalId = '0x1';
    choice = utils.choice.Choice.FOR;
    usedVotingStrategies2 = ['0x0'];
    userVotingParamsAll2 = [[]];
    usedVotingStrategiesHash2 = computeHashOnElements(usedVotingStrategies2);
    const userVotingStrategyParamsFlat2 = utils.encoding.flatten2DArray(userVotingParamsAll2);
    userVotingStrategyParamsFlatHash2 = computeHashOnElements(userVotingStrategyParamsFlat2);
    voteCalldata = utils.encoding.getVoteCalldata(
      voterAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Should not authenticate an invalid proposal', async () => {
    const proposalSalt = '0x01';
    const incorrectSpace = '0x1337';

    const message = {
      authenticator: starkSigAuth.address,
      space: spaceAddress,
      proposerAddress: proposerAddress,
      metadataURI: metadataUriInts.values,
      executor: vanillaExecutionStrategy.address,
      executionParamsHash: executionHash,
      usedVotingStrategiesHash: usedVotingStrategiesHash1,
      userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash1,
      salt: proposalSalt,
    };
    const data: typedData.TypedData = {
      types: proposeTypes,
      primaryType: 'Propose',
      domain,
      message,
    };
    const sig = await user.account.signMessage(data);

    const [r, s] = sig;

    try {
      console.log('Replaying transaction...');
      await controller.invoke(starkSigAuth, 'authenticate', {
        r: r,
        s: s,
        salt: proposalSalt,
        target: incorrectSpace,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });
      throw { message: 'invalid payload was authenticated by signature' };
    } catch (err: any) {
      expect(err.message).to.contain('is invalid, with respect to the public key');
    }
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      const proposalSalt = '0x01';

      const message = {
        authenticator: starkSigAuth.address,
        space: spaceAddress,
        proposerAddress: proposerAddress,
        metadataURI: metadataUriInts.values,
        executor: vanillaExecutionStrategy.address,
        executionParamsHash: executionHash,
        usedVotingStrategiesHash: usedVotingStrategiesHash1,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash1,
        salt: proposalSalt,
      };
      const data: typedData.TypedData = {
        types: proposeTypes,
        primaryType: 'Propose',
        domain,
        message,
      };
      const sig = await user.account.signMessage(data);

      const [r, s] = sig;

      console.log('Creating proposal...');
      await controller.invoke(starkSigAuth, 'authenticate', {
        r: r,
        s: s,
        salt: proposalSalt,
        target: spaceAddress,
        function_selector: PROPOSE_SELECTOR,
        calldata: proposeCalldata,
      });

      // -- Attempts a replay attack on `propose` method --
      // Expected to fail
      try {
        console.log('Replaying transaction...');
        await controller.invoke(starkSigAuth, 'authenticate', {
          r: r,
          s: s,
          salt: proposalSalt,
          target: spaceAddress,
          function_selector: PROPOSE_SELECTOR,
          calldata: proposeCalldata,
        });
        throw { message: 'replay attack worked on `propose`' };
      } catch (err: any) {
        expect(err.message).to.contain('Salt already used');
      }
    }

    // -- Casts a vote FOR --
    {
      console.log('Casting a vote FOR...');
      const voteSalt = '0x02';

      const message = {
        authenticator: starkSigAuth.address,
        space: spaceAddress,
        voterAddress: voterAddress,
        proposal: proposalId,
        choice: utils.choice.Choice.FOR,
        usedVotingStrategiesHash: usedVotingStrategiesHash2,
        userVotingStrategyParamsFlatHash: userVotingStrategyParamsFlatHash2,
        salt: voteSalt,
      };
      const data = { types: voteTypes, primaryType: 'Vote', domain, message };
      const [r, s] = await user.account.signMessage(data);

      await controller.invoke(starkSigAuth, 'authenticate', {
        r: r,
        s: s,
        salt: voteSalt,
        target: spaceAddress,
        function_selector: VOTE_SELECTOR,
        calldata: voteCalldata,
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
        await controller.invoke(starkSigAuth, 'authenticate', {
          r: r,
          s: s,
          salt: voteSalt,
          target: spaceAddress,
          function_selector: VOTE_SELECTOR,
          calldata: voteCalldata,
        });
        throw { message: 'replay attack worked on `vote`' };
      } catch (err: any) {
        expect(err.message).to.contain('Salt already used');
      }
    }
  }).timeout(6000000);
});
