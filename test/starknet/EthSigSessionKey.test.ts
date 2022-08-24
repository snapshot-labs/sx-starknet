import { expect } from 'chai';
import { StarknetContract, Account } from 'hardhat/types';
import { ethers } from 'hardhat';
import { domain, SessionKey, sessionKeyTypes } from '../shared/types';
import { utils } from '@snapshot-labs/sx';
import { ethereumSigSessionKeyAuthSetup } from '../shared/setup';

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
      const salt: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromHex('0x01');
      const message: SessionKey = {
        address: utils.encoding.hexPadRight(accounts[0].address),
        sessionPublicKey: utils.encoding.hexPadRight('0x1234'),
        sessionDuration: utils.encoding.hexPadRight('0x1111'),
        salt: salt.toHex(),
      };
      const sig = await accounts[0]._signTypedData(domain, sessionKeyTypes, message);
      const { r, s, v } = utils.encoding.getRSVFromSig(sig);
      await controller.invoke(ethSigSessionKeyAuth, 'generate_session_key_from_sig', {
        r: r,
        s: s,
        v: v,
        salt: salt,
        eth_address: accounts[0].address,
        session_public_key: '0x1234',
        session_duration: '0x1111',
      });
      const { session_public_key } = await ethSigSessionKeyAuth.call('get_session_key', {
        session_public_key: '0x1234',
      });
      console.log(session_public_key);
    }
  }).timeout(6000000);
});
