import { stark } from 'starknet';
import { SplitUint256, Choice } from '../shared/types';
import { createExecutionHash, flatten2DArray } from '../shared/helpers';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import { ethereumSigSetup } from '../shared/setup';
import { StarknetContract, Account } from 'hardhat/types';
import { ethers } from 'hardhat';
import { domain, Propose, proposeTypes} from './helper/types';
import { _TypedDataEncoder } from '@ethersproject/hash';
import { TypedDataDomain, TypedDataField } from '@ethersproject/abstract-signer';
import { recoverPublicKey, verifyMessage, verifyTypedData, toUtf8Bytes, computePublicKey, computeAddress, keccak256, hexConcat, hexZeroPad } from 'ethers/lib/utils';
import { type } from 'os';
import { keccak } from 'ethereumjs-util';
import { Signature } from 'ethers';


const { getSelectorFromName } = stark;

export const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
export const AUTHENTICATE_METHOD = 'authenticate';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';

export 

function getHash(domain: TypedDataDomain, types: Record<string, TypedDataField[]>, message: Record<string, any>) {
  console.log("Domain:", domain);
  console.log("Types: ", types);
  console.log("Message: ", message);

  const msgHash = _TypedDataEncoder.hash(domain, types, message);

  // hashstruct domain
  const hashDomain = _TypedDataEncoder.hashDomain(domain);
  console.log("official hashDomain: ", hashDomain);

  // Reconstruct hash domain
  const domainFields = [{name: 'name', type: 'string'}, {name: 'version', type: 'string'}]
  let domainHash = _TypedDataEncoder.hashStruct("EIP712Domain", { EIP712Domain: domainFields }, domain);
  console.log("recovered Domain Hash: ", domainHash);

  let dataHash = _TypedDataEncoder.from(types).hash(message);

  const prop = "Propose(uint256 salt,bytes32 space,bytes32 executionHash)";
  let s = Buffer.from(prop);
  let typeHash: string = keccak256(s);
  console.log("typeHash: ", typeHash);
  let encodedData: string = hexConcat([prefixWithZeroes("1"), message.space, message.executionHash]);

  console.log("Encoded Data: ", encodedData)
  let struct = hexConcat([typeHash, encodedData]);
  console.log("struct: ", struct);
  let hashStruct = keccak256(struct);
  console.log("official dataHash:  ", dataHash);
  console.log("Recovered dataHash: ", hashStruct);
  console.log("Equal? ", hashStruct === dataHash);

  const recoveredMsgHash = keccak256(hexConcat(["0x1901", domainHash, hashStruct]));
  console.log("recovered msg hash: ", recoveredMsgHash);
  console.log("msg hash: ", msgHash);
  console.log("RES GOOD? ", msgHash === recoveredMsgHash )
  return msgHash;
}

function prefixWithZeroes(s: string) {
  // Remove prefix
  if (s.startsWith('0x')) {
    s = s.substring(2)
  }

  let numZeroes = 64 - s.length
  return ('0x' + '0'.repeat(numZeroes) + s)
}

function hexPadRight(s: string) {
  // Remove prefix
  if (s.startsWith('0x')) {
    s = s.substring(2)
  }

  // Odd length, need to prefix with a 0
  if (s.length % 2 != 0) {
    s = "0" + s;
  }

  let numZeroes = 64 - s.length
  return ('0x' + s + '0'.repeat(numZeroes))
}

function getRSVFromSig(sig: string) {
  const r = SplitUint256.fromHex('0x' + sig.substring(0, 64));
  const s = SplitUint256.fromHex('0x' + sig.substring(64, 64 * 2));
  const v = BigInt('0x' + sig.substring(64 * 2));
  return {r, s, v}
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

    const accounts = await ethers.getSigners()
    proposerAddress = BigInt(await accounts[0].getAddress())

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
      const fake_data = [...calldata];
      fake_data[0] = VITALIK_ADDRESS;

      await account.invoke(starknetSigAuth, AUTHENTICATE_METHOD, {
        target: spaceContract,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata: fake_data,
      });
      throw 'error';
    } catch (err: any) {
      expect(err.message).to.contain('Incorrect caller');
    }
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      const salt: SplitUint256 = SplitUint256.fromUint(BigInt("1"));
      const spaceStr = hexPadRight(spaceContract.toString(16));
      const executionHashStr = hexPadRight(executionHash.toHex());
      console.log("space str before: ", spaceStr);
      const message: Propose = {salt: 1, space: spaceStr, executionHash: executionHashStr};

      const msgHash = getHash(domain, proposeTypes, message);

      const accounts = await ethers.getSigners();
      let sig = await accounts[0]._signTypedData(domain, proposeTypes, message);
      console.log("Sig: ", sig);

      // Remove '0x' prefix
      sig = sig.substring(2);

      const {r, s, v} = getRSVFromSig(sig)

      const msg_hash_uint256 = SplitUint256.fromHex(msgHash);

      console.log('Creating proposal...');
      await account.invoke(starknetSigAuth, AUTHENTICATE_METHOD, {
        msg_hash: msg_hash_uint256,
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
    // {
    //   console.log('Casting a vote FOR...');
    //   const voter_address = proposerAddress;
    //   const votingparams: Array<BigInt> = [];
    //   const used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
    //   await account.invoke(starknetSigAuth, AUTHENTICATE_METHOD, {
    //     target: spaceContract,
    //     function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
    //     calldata: [
    //       voter_address,
    //       proposalId,
    //       Choice.FOR,
    //       BigInt(used_voting_strategies.length),
    //       ...used_voting_strategies,
    //       BigInt(votingParamsAllFlat.length),
    //       ...votingParamsAllFlat,
    //     ],
    //   });

    //   console.log('Getting proposal info...');
    //   const { proposal_info } = await vanillaSpace.call('get_proposal_info', {
    //     proposal_id: proposalId,
    //   });

    //   const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
    //   expect(_for).to.deep.equal(BigInt(1));
    //   const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
    //   expect(against).to.deep.equal(BigInt(0));
    //   const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
    //   expect(abstain).to.deep.equal(BigInt(0));
    // }
  }).timeout(6000000);
});
