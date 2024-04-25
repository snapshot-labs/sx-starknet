import dotenv from 'dotenv';
import { starknet, ethers } from 'hardhat';
import { CallData, typedData, cairo, shortString, Account, Provider } from 'starknet';
import { sessionKeyAuthTypes, SessionKeyAuth } from './eth-sig-types';
import { proposeTypes, Propose } from './stark-sig-types';
import { getRSVFromSig } from './utils';

dotenv.config();

const account_address = process.env.ADDRESS || '';
const account_pk = process.env.PK || '';
const account_public_key = process.env.PUBLIC_KEY || '';
const network = process.env.STARKNET_NETWORK_URL || '';

describe('Ethereum Signature Authenticator', function () {
  this.timeout(1000000);

  // Ethereum EIP712 Domain is empty.
  const ethDomain = {};

  let signer: ethers.HDNodeWallet;

  let account: starknet.starknetAccount;
  // SNIP-6 compliant account (the defaults deployed on the devnet are not SNIP-6 compliant and therefore cannot be used for s)
  let accountWithSigner: Account;
  let ethSigSessionKeyAuthenticator: starknet.StarknetContract;
  let vanillaVotingStrategy: starknet.StarknetContract;
  let vanillaProposalValidationStrategy: starknet.StarknetContract;
  let space: starknet.StarknetContract;

  let starkDomain: any;

  before(async function () {
    signer = ethers.Wallet.createRandom();
    account = await starknet.OpenZeppelinAccount.getAccountFromAddress(account_address, account_pk);

    const accountFactory = await starknet.getContractFactory('openzeppelin_Account');
    const ethSigSessionKeyAuthenticatorFactory = await starknet.getContractFactory(
      'sx_EthSigSessionKeyAuthenticator',
    );
    const vanillaVotingStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaVotingStrategy',
    );
    const vanillaProposalValidationStrategyFactory = await starknet.getContractFactory(
      'sx_VanillaProposalValidationStrategy',
    );
    const spaceFactory = await starknet.getContractFactory('sx_Space');

    try {
      // If the contracts are already declared, this will be skipped
      await account.declare(accountFactory);
      await account.declare(ethSigSessionKeyAuthenticatorFactory);
      await account.declare(vanillaVotingStrategyFactory);
      await account.declare(vanillaProposalValidationStrategyFactory);
      await account.declare(spaceFactory);
    } catch {}

    const accountObj = await account.deploy(accountFactory, {
      _public_key: account_public_key,
    });

    accountWithSigner = new Account(
      new Provider({ sequencer: { baseUrl: network } }),
      accountObj.address,
      account_pk,
    );

    ethSigSessionKeyAuthenticator = await account.deploy(ethSigSessionKeyAuthenticatorFactory, {
      name: shortString.encodeShortString('sx-sn'),
      version: shortString.encodeShortString('0.1.0'),
    });
    vanillaVotingStrategy = await account.deploy(vanillaVotingStrategyFactory);
    vanillaProposalValidationStrategy = await account.deploy(
      vanillaProposalValidationStrategyFactory,
    );
    space = await account.deploy(spaceFactory);

    // Initializing the space
    const initializeCalldata = CallData.compile({
      _owner: 1,
      _max_voting_duration: 200,
      _min_voting_duration: 200,
      _voting_delay: 100,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategy.address,
        params: [],
      },
      _proposal_validation_strategy_metadata_uri: [],
      _voting_strategies: [{ address: vanillaVotingStrategy.address, params: [] }],
      _voting_strategies_metadata_uri: [[]],
      _authenticators: [ethSigSessionKeyAuthenticator.address],
      _metadata_uri: [],
      _dao_uri: [],
    });

    await account.invoke(space, 'initialize', initializeCalldata, { rawInput: true });

    starkDomain = {
      name: 'sx-sn',
      version: '0.1.0',
      chainId: '0x534e5f474f45524c49', // devnet id
      verifyingContract: ethSigSessionKeyAuthenticator.address,
    };

    // Dumping the Starknet state so it can be loaded at the same point for each test
    await starknet.devnet.dump('dump.pkl');
  }, 10000000);

  it('can authenticate a proposal, a vote, and a proposal update', async () => {
    await starknet.devnet.restart();
    await starknet.devnet.load('./dump.pkl');
    await starknet.devnet.increaseTime(10);

    // Register Session
    const sessionKeyAuthMsg: SessionKeyAuth = {
      chainId: '0x534e5f474f45524c49',
      authenticator: ethSigSessionKeyAuthenticator.address,
      owner: signer.address,
      sessionPublicKey: '0x123',
      sessionDuration: '0x123',
      salt: '0x0',
    };

    let sig = await signer._signTypedData(ethDomain, sessionKeyAuthTypes, sessionKeyAuthMsg);
    let splitSig = getRSVFromSig(sig);

    const sessionKeyAuthCalldata = CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      owner: sessionKeyAuthMsg.owner,
      sessionPublicKey: sessionKeyAuthMsg.sessionPublicKey,
      sessionDuration: sessionKeyAuthMsg.sessionDuration,
      salt: cairo.uint256(sessionKeyAuthMsg.salt),
    });

    await account.invoke(
      ethSigSessionKeyAuthenticator,
      'register_with_owner_sig',
      sessionKeyAuthCalldata,
      {
        rawInput: true,
      },
    );

    // Propose
    const proposeMsg: Propose = {
      space: space.address,
      author: sessionKeyAuthMsg.owner,
      metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      executionStrategy: {
        address: '0x0000000000000000000000000000000000005678',
        params: ['0x0'],
      },
      userProposalValidationParams: [
        '0xffffffffffffffffffffffffffffffffffffffffff',
        '0x1234',
        '0x5678',
        '0x9abc',
      ],
      salt: '0x1',
    };

    const proposeSig = (await accountWithSigner.signMessage({
      types: proposeTypes,
      primaryType: 'Propose',
      domain: starkDomain,
      message: proposeMsg as any,
    } as typedData.TypedData)) as any;

    const proposeCalldata = CallData.compile({
      signature: [proposeSig.r, proposeSig.s],
      ...proposeMsg,
      session_public_key: sessionKeyAuthMsg.sessionPublicKey,
    });

    await account.invoke(ethSigSessionKeyAuthenticator, 'authenticate_propose', proposeCalldata, {
      rawInput: true,
    });
  }, 1000000);
});
