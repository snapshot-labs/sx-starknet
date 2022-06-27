import { hash } from 'starknet';
import { SplitUint256, Choice } from '../shared/types';
import { flatten2DArray } from '../shared/helpers';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import { ethereumSigSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { ethers } from 'hardhat';
import { domain, Propose, proposeTypes, Vote, voteTypes } from './helper/types';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { TypedDataDomain, TypedDataField } from '@ethersproject/abstract-signer';
import { getProposeCalldata, getVoteCalldata, bytesToHex } from '../shared/helpers';

const { getSelectorFromName } = hash;

export const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
export const AUTHENTICATE_METHOD = 'authenticate';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';

function getHash(
  domain: TypedDataDomain,
  types: Record<string, TypedDataField[]>,
  message: Record<string, any>
) {
  const msgHash = _TypedDataEncoder.hash(domain, types, message);

  // Stub code to generate and print the type hash
  // const vote = "Vote(uint256 salt,bytes32 space,uint256 proposal,uint256 choice)";
  // let s = Buffer.from(vote);
  // let typeHash: string = keccak256(s);
  // console.log("typeHash: ", typeHash);

  return msgHash;
}

function prefixWithZeroes(s: string) {
  // Remove prefix
  if (s.startsWith('0x')) {
    s = s.substring(2);
  }

  const numZeroes = 64 - s.length;
  return '0x' + '0'.repeat(numZeroes) + s;
}

function hexPadRight(s: string) {
  // Remove prefix
  if (s.startsWith('0x')) {
    s = s.substring(2);
  }

  // Odd length, need to prefix with a 0
  if (s.length % 2 != 0) {
    s = '0' + s;
  }

  const numZeroes = 64 - s.length;
  return '0x' + s + '0'.repeat(numZeroes);
}

// Extracts and returns the `r, s, v` values from a `signature`.
// `r`, `s` are SplitUint256, `v` is a BigInt
function getRSVFromSig(sig: string) {
  if (sig.startsWith('0x')) {
    sig = sig.substring(2);
  }
  const r = SplitUint256.fromHex('0x' + sig.substring(0, 64));
  const s = SplitUint256.fromHex('0x' + sig.substring(64, 64 * 2));
  const v = BigInt('0x' + sig.substring(64 * 2));
  return { r, s, v };
}

describe('Ethereum Sig Auth testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let ethSigAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;

  // Proposal creation parameters
  let spaceAddress: bigint;
  let executionHash: string;
  let metadataUri: bigint[];
  let usedVotingStrategies1: bigint[];
  let userVotingParamsAll1: bigint[][];
  let executionStrategy: bigint;
  let executionParams: bigint[];
  let proposerEthAddress: string;
  let proposeCalldata: bigint[];

  // Additional parameters for voting
  let voterEthAddress: string;
  let proposalId: bigint;
  let choice: Choice;
  let usedVotingStrategies2: bigint[];
  let userVotingParamsAll2: bigint[][];
  let voteCalldata: bigint[];

  before(async function () {
    this.timeout(800000);

    ({ space, controller, ethSigAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await ethereumSigSetup());

    executionHash = bytesToHex(ethers.utils.randomBytes(32)); // Random 32 byte hash
    const accounts = await ethers.getSigners();
    metadataUri = strToShortStringArr(
      'Hello and welcome to Snapshot X. This is the future of governance.'
    );
    spaceAddress = BigInt(space.address);
    usedVotingStrategies1 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll1 = [[]];
    executionStrategy = BigInt(vanillaExecutionStrategy.address);
    executionParams = [];
    proposerEthAddress = accounts[0].address;
    proposeCalldata = getProposeCalldata(
      proposerEthAddress,
      executionHash,
      metadataUri,
      executionStrategy,
      usedVotingStrategies1,
      userVotingParamsAll1,
      executionParams
    );

    voterEthAddress = accounts[0].address;
    proposalId = BigInt(1);
    choice = Choice.FOR;
    usedVotingStrategies2 = [BigInt(vanillaVotingStrategy.address)];
    userVotingParamsAll2 = [[]];
    voteCalldata = getVoteCalldata(
      voterEthAddress,
      proposalId,
      choice,
      usedVotingStrategies2,
      userVotingParamsAll2
    );
  });

  it('Should not authenticate an invalid signature', async () => {
    try {
      const salt: SplitUint256 = SplitUint256.fromHex('0x1');
      const spaceStr = hexPadRight(space.address);
      const executionHashStr = hexPadRight(executionHash);
      const message: Propose = { salt: 1, space: spaceStr, executionHash: executionHashStr };

      const fake_data = [...proposeCalldata];

      const accounts = await ethers.getSigners();
      const sig = await accounts[0]._signTypedData(domain, proposeTypes, message);
      const { r, s, v } = getRSVFromSig(sig);

      // Data is signed with accounts[0] but the proposer is accounts[1] so it should fail
      fake_data[0] = BigInt(accounts[1].address);

      await controller.invoke(ethSigAuth, AUTHENTICATE_METHOD, {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata: fake_data,
      });
      console.log('5');
      throw 'error';
    } catch (err: any) {
      expect(err.message).to.contain('Invalid signature.');
    }
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      const accounts = await ethers.getSigners();
      const salt: SplitUint256 = SplitUint256.fromHex('0x1');
      const spaceStr = hexPadRight(space.address);
      const executionHashStr = hexPadRight(executionHash);
      const message: Propose = { salt: 1, space: spaceStr, executionHash: executionHashStr };
      const proposerEthAddress = accounts[0].address;
      const proposeCalldata = getProposeCalldata(
        proposerEthAddress,
        executionHash,
        metadataUri,
        executionStrategy,
        usedVotingStrategies1,
        userVotingParamsAll1,
        executionParams
      );

      const sig = await accounts[0]._signTypedData(domain, proposeTypes, message);

      const { r, s, v } = getRSVFromSig(sig);

      console.log('Creating proposal...');
      await controller.invoke(ethSigAuth, AUTHENTICATE_METHOD, {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata: proposeCalldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      // -- Attempts a replay attack on `propose` method --
      // Expected to fail
      try {
        await controller.invoke(ethSigAuth, AUTHENTICATE_METHOD, {
          r: r,
          s: s,
          v: v,
          salt: salt,
          target: spaceAddress,
          function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
          calldata: proposeCalldata,
        });
        throw 'replay attack worked on `propose`';
      } catch (err: any) {
        expect(err.message).to.contain('Salt already used');
      }

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element.
      const _executionHash = SplitUint256.fromObj(proposal_info.proposal.execution_hash);
      expect(_executionHash).to.deep.equal(SplitUint256.fromHex(executionHash));

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // -- Casts a vote FOR --
    {
      console.log('Casting a vote FOR...');
      const accounts = await ethers.getSigners();
      const spaceStr = hexPadRight(space.address);
      const message: Vote = { salt: 2, space: spaceStr, proposal: 1, choice: Choice.FOR };
      const sig = await accounts[0]._signTypedData(domain, voteTypes, message);

      const { r, s, v } = getRSVFromSig(sig);
      const salt = SplitUint256.fromHex('0x02');
      const voteCalldata = getVoteCalldata(
        voterEthAddress,
        proposalId,
        Choice.FOR,
        usedVotingStrategies1,
        userVotingParamsAll1
      );
      await controller.invoke(ethSigAuth, AUTHENTICATE_METHOD, {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: voteCalldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));

      // -- Attempts a replay attack on `vote` method --
      try {
        await controller.invoke(ethSigAuth, AUTHENTICATE_METHOD, {
          r: r,
          s: s,
          v: v,
          salt: salt,
          target: spaceAddress,
          function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
          calldata: voteCalldata,
        });
        throw 'replay attack worked on `vote`';
      } catch (err: any) {
        expect(err.message).to.contain('Salt already used');
      }
    }
  }).timeout(6000000);
});
