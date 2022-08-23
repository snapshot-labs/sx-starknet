import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import { ethers } from 'hardhat';
import { domain, SessionKey, sessionKeyTypes } from '../shared/types';
import { computeHashOnElements } from 'starknet/dist/utils/hash';
import { utils } from '@snapshot-labs/sx';
import { ethereumSigSessionKeyAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR, VOTE_SELECTOR } from '../shared/constants';

export const VITALIK_ADDRESS = BigInt('0xd8da6bf26964af9d7eed9e03e53415d37aa96045');
export const AUTHENTICATE_METHOD = 'authenticate';
export const PROPOSAL_METHOD = 'propose';
export const VOTE_METHOD = 'vote';
export const METADATA_URI = 'Hello and welcome to Snapshot X. This is the future of governance.';

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

describe('Ethereum Sig Auth testing', () => {
  // Contracts
  let space: StarknetContract;
  let controller: Account;
  let ethSigSessionKeyAuth: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;



  before(async function () {
    this.timeout(800000);
    const accounts = await ethers.getSigners();
    ({ space, controller, ethSigSessionKeyAuth, vanillaVotingStrategy, vanillaExecutionStrategy } =
      await ethereumSigSessionKeyAuthSetup());

  });

  it('Should generate a session key if a valid signature is provided', async () => {
    // -- Creates the proposal --
    {
      const accounts = await ethers.getSigners();
      const salt: utils.splitUint256.SplitUint256 =
        utils.splitUint256.SplitUint256.fromHex('0x01');

      const message: SessionKey = {
        address: utils.encoding.hexPadRight(accounts[0].address),
        sessionPublicKey: utils.encoding.hexPadRight('0x1234'),
        sessionDuration: utils.encoding.hexPadRight('0x1111'),
        salt: salt.toHex(),
      };

      const sig = await accounts[0]._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      console.log('eth address: ', accounts[0].address);
      console.log('Creating proposal...');
      await controller.invoke(ethSigSessionKeyAuth, 'generate_session_key_from_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: accounts[0].address,
        session_public_key: '0x1234',
        session_duration: '0x1111'
      });

      console.log('Checking...');
      const { session_public_key } = await ethSigSessionKeyAuth.call('get_session_key', {
        session_public_key: '0x1234',
      });
      console.log(session_public_key);
    }
  }).timeout(6000000);
});
