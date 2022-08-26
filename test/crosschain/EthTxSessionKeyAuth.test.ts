import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Contract } from 'ethers';
import { starknet, network, ethers } from 'hardhat';
import { StarknetContract, Account, HttpNetworkConfig } from 'hardhat/types';
import { utils } from '@snapshot-labs/sx';
import { ethTxSessionKeyAuthSetup } from '../shared/setup';
import { PROPOSE_SELECTOR } from '../shared/constants';

import { hash } from 'starknet';
const { computeHashOnElements } = hash;

function getCommit(ethAddress: string, sessionPublicKey: string, sessionDuration: string): string {
  return computeHashOnElements([ethAddress, sessionPublicKey, sessionDuration]);
}

describe('Ethereum Transaction Session Keys', function () {
  this.timeout(5000000);
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let account: SignerWithAddress;

  // Contracts
  let mockStarknetMessaging: Contract;
  let space: StarknetContract;
  let ethTxSessionKeyAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let vanillaExecutionStrategy: StarknetContract;
  let starknetCommit: Contract;

  // Session
  let ethAddress: string;
  let sessionPublicKey: string;
  let sessionDuration: string;

  before(async function () {
    const accounts = await ethers.getSigners();
    account = accounts[0];

    ethAddress = account.address;
    sessionPublicKey = '0x1234';
    sessionDuration = '0x1111';

    ({
      space,
      ethTxSessionKeyAuthenticator,
      vanillaVotingStrategy,
      vanillaExecutionStrategy,
      mockStarknetMessaging,
      starknetCommit,
    } = await ethTxSessionKeyAuthSetup());
  });

  it('should authorize a session key from an L1 transaction', async () => {
    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
    // Committing the hash of the payload to the StarkNet Commit L1 contract
    await starknetCommit
      .connect(account)
      .commit(
        ethTxSessionKeyAuthenticator.address,
        getCommit(ethAddress, sessionPublicKey, sessionDuration)
      );
    // Checking that the L1 -> L2 message has been propogated
    expect((await starknet.devnet.flush()).consumed_messages.from_l1).to.have.a.lengthOf(1);
    // Creating proposal
    await ethTxSessionKeyAuthenticator.invoke('authorize_session_key_from_tx', {
      eth_address: ethAddress,
      session_public_key: sessionPublicKey,
      session_duration: sessionDuration,
    });
  });
});
