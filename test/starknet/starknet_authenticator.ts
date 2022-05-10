import { ec, hash, Provider, Signer, stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import {
  starknetSetup,
  VITALIK_ADDRESS,
  EXECUTE_METHOD,
  PROPOSAL_METHOD,
} from './shared/setup';
import { StarknetContract } from 'hardhat/types';
import { Account } from '@shardlabs/starknet-hardhat-plugin/dist/account';
import { computeHashOnElements, hashCalldata } from 'starknet/dist/utils/hash';
import { toBN } from 'starknet/dist/utils/number';

const { getSelectorFromName } = stark;

describe('Starknet Auth', () => {
  let vanillaSpace: StarknetContract;
  let starknetAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let account: Account;
  const executionHash = new SplitUint256(BigInt(1), BigInt(2)); // Dummy uint256
  const metadataUri = strToShortStringArr(
    'Hello and welcome to Snapshot X. This is the future of governance.'
  );
  const proposerAddress = { value: VITALIK_ADDRESS };
  const proposalId = 1;
  const votingParams: Array<bigint> = [];
  let executionParams: Array<bigint>;
  const ethBlockNumber = BigInt(1337);
  const l1_zodiac_module = BigInt('0xaaaaaaaaaaaa');
  let calldata: Array<bigint>;
  let calldata2: Array<bigint>;
  let spaceContract: bigint;

  before(async function () {
    this.timeout(800000);

    ({ vanillaSpace, starknetAuthenticator, vanillaVotingStrategy, zodiacRelayer, account } =
      await starknetSetup());
    executionParams = [BigInt(l1_zodiac_module)];
    spaceContract = BigInt(vanillaSpace.address);

    calldata = [
      proposerAddress.value,
      executionHash.low,
      executionHash.high,
      BigInt(metadataUri.length),
      ...metadataUri,
      ethBlockNumber,
      BigInt(zodiacRelayer.address),
      BigInt(votingParams.length),
      ...votingParams,
      BigInt(executionParams.length),
      ...executionParams,
    ];
  });

  it('Should authenticate a valid key', async () => {
    const privateKey = stark.randomAddress();
    const starkKeyPair = ec.getKeyPair(privateKey);
    const defaultProvider = new Provider();
    const addr = "";
    const signer = new Signer(defaultProvider, addr, starkKeyPair);
    const calldataBigNum = calldata.map((x) => toBN('0x' + x.toString(16)));
    const msg_hash = BigInt(computeHashOnElements(calldataBigNum));
    const sig = await signer.signMessage();
    console.log("sig: ", sig);
    console.log("1: ", sig[0]);
    console.log("2: ", sig[1]);
    await starknetAuthenticator.invoke(EXECUTE_METHOD, {
      target: spaceContract,
      function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
      calldata,
      signer: [],
      signature: [],
    });
  });

  // it('Should NOT authenticate an INVALID key', async () => {
  //   {
  //     await starknetAuthenticator.invoke(EXECUTE_METHOD, {
  //       target: spaceContract,
  //       function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
  //       calldata,
  //       signer: [],
  //       signature: [],
  //     });
  //   }
  // });
});
