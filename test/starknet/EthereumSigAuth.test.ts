import { stark } from 'starknet';
import { SplitUint256, Choice } from '../shared/types';
import { createExecutionHash, flatten2DArray } from '../shared/helpers';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import { ethereumSigSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { ethers } from 'hardhat';
import { domain, Propose, proposeTypes, Vote, voteTypes } from './helper/types';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { TypedDataDomain, TypedDataField } from '@ethersproject/abstract-signer';
import {
  recoverPublicKey,
  verifyMessage,
  verifyTypedData,
  toUtf8Bytes,
  computePublicKey,
  computeAddress,
  keccak256,
  hexConcat,
  hexZeroPad,
  serializeTransaction,
} from 'ethers/lib/utils';
import { type } from 'os';
import { keccak } from 'ethereumjs-util';
import { Signature } from 'ethers';

const { getSelectorFromName } = stark;

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
  let vanillaSpace: StarknetContract;
  let starknetSigAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  const executionHash = new SplitUint256(BigInt(3), BigInt(0)); // Dummy uint256
  const metadataUri = strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  let proposerAddress: bigint;
  const proposalId = 1;
  const votingParamsAll: bigint[][] = [[]];
  const votingParamsAllFlat = flatten2DArray(votingParamsAll);
  let used_voting_strategies: Array<bigint>;
  let executionParams: Array<bigint>;
  const ethBlockNumber = BigInt(1337);
  const l1_zodiac_module = BigInt('0xaaaaaaaaaaaa');
  let calldata: Array<bigint>;
  let spaceContract: bigint;
  let account: Account;

  before(async function () {
    this.timeout(800000);

    ({ vanillaSpace, starknetSigAuth, vanillaVotingStrategy, zodiacRelayer, account } =
      await ethereumSigSetup());
    executionParams = [BigInt(l1_zodiac_module)];
    spaceContract = BigInt(vanillaSpace.address);
    used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];

    const accounts = await ethers.getSigners();
    proposerAddress = BigInt(await accounts[0].getAddress());

    calldata = [
      BigInt(accounts[0].address),
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(zodiacRelayer.address),
      BigInt(used_voting_strategies.length),
      ...used_voting_strategies,
      BigInt(votingParamsAllFlat.length),
      ...votingParamsAllFlat,
      BigInt(executionParams.length),
      ...executionParams,
    ];
  });

  it('Should not authenticate an invalid signature', async () => {
    try {
      const salt: SplitUint256 = SplitUint256.fromHex('0x1');
      const spaceStr = hexPadRight(spaceContract.toString(16));
      const executionHashStr = hexPadRight(executionHash.toHex());
      console.log('space str before: ', spaceStr);
      const message: Propose = { salt: 1, space: spaceStr, executionHash: executionHashStr };
      const fake_data = [...calldata];
      const accounts = await ethers.getSigners();

      const sig = await accounts[0]._signTypedData(domain, proposeTypes, message);
      const { r, s, v } = getRSVFromSig(sig);

      // Data is signed with accounts[0] but the proposer is accounts[1] so it should fail
      fake_data[0] = BigInt(accounts[1].address);

      await account.invoke(starknetSigAuth, AUTHENTICATE_METHOD, {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata: fake_data,
      });
      throw 'error';
    } catch (err: any) {
      expect(err.message).to.contain('Invalid signature.');
    }
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      const salt: SplitUint256 = SplitUint256.fromHex('0x1');
      const spaceStr = hexPadRight(spaceContract.toString(16));
      const executionHashStr = hexPadRight(executionHash.toHex());
      console.log('space str before: ', spaceStr);
      const message: Propose = { salt: 1, space: spaceStr, executionHash: executionHashStr };

      const msgHash = getHash(domain, proposeTypes, message);

      const accounts = await ethers.getSigners();
      const sig = await accounts[0]._signTypedData(domain, proposeTypes, message);
      console.log('Sig: ', sig);

      const { r, s, v } = getRSVFromSig(sig);


      console.log('Creating proposal...');
      await account.invoke(starknetSigAuth, AUTHENTICATE_METHOD, {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata,
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element.
      const _executionHash = SplitUint256.fromObj(proposal_info.proposal.execution_hash);
      expect(_executionHash).to.deep.equal(executionHash);

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
      const voter_address = BigInt(accounts[0].address);
      const votingparams: Array<BigInt> = [];
      const used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
      const spaceStr = hexPadRight(spaceContract.toString(16));
      const message: Vote = { salt: 2, space: spaceStr, proposal: proposalId, choice: Choice.FOR };
      const sig = await accounts[0]._signTypedData(domain, voteTypes, message);
      const { r, s, v } = getRSVFromSig(sig);
      const salt = SplitUint256.fromHex('0x02');
      await account.invoke(starknetSigAuth, AUTHENTICATE_METHOD, {
        r: r,
        s: s,
        v: v,
        salt: salt,
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
        calldata: [
          voter_address,
          proposalId,
          Choice.FOR,
          BigInt(used_voting_strategies.length),
          ...used_voting_strategies,
          BigInt(votingParamsAllFlat.length),
          ...votingParamsAllFlat,
        ],
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(1));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }
  }).timeout(6000000);
});
