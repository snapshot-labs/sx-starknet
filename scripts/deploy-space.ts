import * as dotenv from 'dotenv';
import * as fs from 'fs';
import { RpcProvider, Account, json, CallData, cairo, ETransactionVersion, hash } from 'starknetV9';

dotenv.config();

const accountAddress = process.env.ADDRESS || '';
const accountPk = process.env.PK || '';
const starknetNetworkUrl = process.env.STARKNET_NETWORK_URL || '';
const l1ChainId = process.env.L1_CHAIN_ID || '';
const satelliteContractAddress = process.env.HERODOTUS_SATELLITE_ADDRESS || '';
const l1TokenAddress = process.env.L1_TOKEN_ADDRESS || '';

// Slot index of _delegateCheckpoints in OZVotesToken (OZ v5), obtained via:
//   cd ethereum && forge inspect OZVotesToken storage-layout
const slotIndex = cairo.uint256(9);

function readContract(baseName: string) {
  const sierra = json.parse(
    fs.readFileSync(`starknet/target/dev/${baseName}.contract_class.json`).toString('ascii'),
  );
  const casm = json.parse(
    fs
      .readFileSync(`starknet/target/dev/${baseName}.compiled_contract_class.json`)
      .toString('ascii'),
  );
  return { sierra, casm };
}

function extractExpectedHash(errorMsg: string): string | null {
  const match = errorMsg.match(/Expected:\s*(0x[0-9a-fA-F]+)/);
  return match ? match[1] : null;
}

async function declareIfNeeded(
  account: Account,
  provider: RpcProvider,
  contract: { sierra: any; casm: any },
): Promise<string> {
  const classHash = hash.computeContractClassHash(contract.sierra);
  console.log(`  Sierra class hash: ${classHash}`);

  try {
    await provider.getClass(classHash);
    console.log(`  Class already declared on network`);
    return classHash;
  } catch {
    console.log(`  Class not yet declared, declaring...`);
  }

  try {
    const declareRes = await account.declare({
      contract: contract.sierra,
      casm: contract.casm,
    });
    console.log(`  Declared class: ${declareRes.class_hash} (tx: ${declareRes.transaction_hash})`);
    await account.waitForTransaction(declareRes.transaction_hash);
    return declareRes.class_hash;
  } catch (e: any) {
    const msg: string =
      e?.baseError?.data?.execution_error || e?.message || JSON.stringify(e) || '';

    if (msg.includes('already declared')) {
      console.log(`  Class already declared (caught during declare): ${classHash}`);
      return classHash;
    }

    const expectedHash = extractExpectedHash(msg);
    if (msg.includes('Mismatch compiled class hash') && expectedHash) {
      console.log(`  Compiled class hash mismatch — local CASM differs from node compiler`);
      console.log(`  Retrying declare with node-expected compiledClassHash: ${expectedHash}`);
      const retryRes = await account.declare({
        contract: contract.sierra,
        casm: contract.casm,
        compiledClassHash: expectedHash,
      });
      console.log(`  Declared class: ${retryRes.class_hash} (tx: ${retryRes.transaction_hash})`);
      await account.waitForTransaction(retryRes.transaction_hash);
      return retryRes.class_hash;
    }

    throw e;
  }
}

async function declareAndDeploy(
  account: Account,
  provider: RpcProvider,
  contract: { sierra: any; casm: any },
  constructorCalldata: any[],
): Promise<string> {
  const classHash = await declareIfNeeded(account, provider, contract);

  const deployRes = await account.deploy({
    classHash,
    constructorCalldata,
  });
  console.log(`  Deployed (tx: ${deployRes.transaction_hash})`);
  await account.waitForTransaction(deployRes.transaction_hash);

  return deployRes.contract_address[0];
}

async function main() {
  const provider = new RpcProvider({ nodeUrl: starknetNetworkUrl });
  const account = new Account({
    provider,
    address: accountAddress,
    signer: accountPk,
    transactionVersion: ETransactionVersion.V3,
  });

  const votingStrategy = readContract('sx_OZVotesTrace208StorageProofVotingStrategy');
  const space = readContract('sx_Space');
  const vanillaAuth = readContract('sx_VanillaAuthenticator');
  const vanillaProposalValidation = readContract('sx_VanillaProposalValidationStrategy');

  // Deploy Vanilla Authenticator
  console.log('Deploying Vanilla Authenticator...');
  const vanillaAuthenticatorAddress = await declareAndDeploy(account, provider, vanillaAuth, []);
  console.log('Vanilla Authenticator Address:', vanillaAuthenticatorAddress);

  // Deploy Vanilla Proposal Validation Strategy
  console.log('Deploying Vanilla Proposal Validation Strategy...');
  const vanillaProposalValidationStrategyAddress = await declareAndDeploy(
    account,
    provider,
    vanillaProposalValidation,
    [],
  );
  console.log(
    'Vanilla Proposal Validation Strategy Address:',
    vanillaProposalValidationStrategyAddress,
  );

  // Deploy OZ Votes Trace208 Storage Proof Voting Strategy
  console.log('Deploying OZ Votes Trace208 Voting Strategy...');
  const votingStrategyAddress = await declareAndDeploy(
    account,
    provider,
    votingStrategy,
    CallData.compile({
      satellite_contract: satelliteContractAddress,
      chain_id: l1ChainId,
    }),
  );
  console.log('Voting Strategy Address:', votingStrategyAddress);

  // Deploy Space
  console.log('Deploying Space...');
  const spaceAddress = await declareAndDeploy(account, provider, space, []);
  console.log('Space Address:', spaceAddress);

  // Initialize space
  console.log('Initializing Space...');
  const initTx = await account.execute({
    contractAddress: spaceAddress,
    entrypoint: 'initialize',
    calldata: CallData.compile({
      _owner: 1,
      _max_voting_duration: 20000,
      _min_voting_duration: 20000,
      _voting_delay: 0,
      _proposal_validation_strategy: {
        address: vanillaProposalValidationStrategyAddress,
        params: [],
      },
      _proposal_validation_strategy_metadata_uri: [],
      _voting_strategies: [
        {
          address: votingStrategyAddress,
          params: [l1TokenAddress, slotIndex.low, slotIndex.high],
        },
      ],
      _voting_strategies_metadata_uri: [[]],
      _authenticators: [vanillaAuthenticatorAddress],
      _metadata_uri: [],
      _dao_uri: [],
    }),
  });
  await account.waitForTransaction(initTx.transaction_hash);
  console.log('Space initialized');

  console.log('\n--- Deployed addresses ---');
  console.log('SPACE_ADDRESS=' + spaceAddress);
  console.log('VANILLA_AUTHENTICATOR_ADDRESS=' + vanillaAuthenticatorAddress);
  console.log('VOTING_STRATEGY_ADDRESS=' + votingStrategyAddress);
}

main();
