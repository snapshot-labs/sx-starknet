import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import { Account as StarknetAccount, ec, defaultProvider, typedData } from 'starknet';
import { ethers } from 'hardhat';
import { domain, SessionKey, sessionKeyTypes } from '../shared/types';
import { utils } from '@snapshot-labs/sx';
import { ethereumSigSessionKeyAuthSetup } from '../shared/setup';

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
  let proposerAddress: string;
  let proposeCalldata: string[];

  // Session Key
  let sessionPublicKey: string;
  let sessionAccount: Account;

  before(async function () {
    this.timeout(800000);
    const accounts = await ethers.getSigners();

    const sessionKeyPair = ec.genKeyPair();
    const sessionPublicKey = ec.getStarkKey(sessionKeyPair);

    // ({ space, controller, ethSigSessionKeyAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
    //   await ethereumSigSessionKeyAuthSetup());
  });

  it('Should generate a session key if a valid signature is provided', async () => {
    // -- Creates the proposal --
    // {
    //   const accounts = await ethers.getSigners();
    //   const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex('0x01');
    //   const message: SessionKey = {
    //     address: utils.encoding.hexPadRight(accounts[0].address),
    //     sessionPublicKey: utils.encoding.hexPadRight('0x1234'),
    //     sessionDuration: utils.encoding.hexPadRight('0x1111'),
    //     salt: salt.toHex(),
    //   };
    //   const sig = await accounts[0]._signTypedData(domain, sessionKeyTypes, message);
    //   const { r, s, v } = utils.encoding.getRSVFromSig(sig);
    //   await controller.invoke(ethSigSessionKeyAuth, 'authorize_session_key_from_sig', {
    //     r: r,
    //     s: s,
    //     v: v,
    //     salt: salt,
    //     eth_address: accounts[0].address,
    //     session_public_key: '0x1234',
    //     session_duration: '0x1111',
    //   });
    //   const { eth_address } = await ethSigSessionKeyAuth.call('get_session_key_owner', {
    //     session_public_key: '0x1234',
    //   });
    //   expect(eth_address).to.deep.equal(BigInt(accounts[0].address));
    // }
  }).timeout(6000000);
});
