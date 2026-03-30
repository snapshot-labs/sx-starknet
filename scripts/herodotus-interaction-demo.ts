import * as dotenv from 'dotenv';
import axios from 'axios';
import { ethers } from 'ethers';
import { RpcProvider, Account, CallData, cairo, Contract, ETransactionVersion } from 'starknetV9';
import { utils } from '@snapshot-labs/sx';

dotenv.config();

const accountAddress = process.env.ADDRESS || '';
const accountPk = process.env.PK || '';
const starknetNetworkUrl = process.env.STARKNET_NETWORK_URL || '';
const ethNetworkUrl = process.env.ETH_NETWORK_URL || '';
const herodotusBaseUrl = process.env.HERODOTUS_BASE_URL || '';
const herodotusApiKey = process.env.HERODOTUS_API_KEY || '';

const spaceAddress = process.env.SPACE_ADDRESS || '';
const vanillaAuthenticatorAddress = process.env.VANILLA_AUTHENTICATOR_ADDRESS || '';
const votingStrategyAddress = process.env.VOTING_STRATEGY_ADDRESS || '';
const l1TokenAddress = process.env.L1_TOKEN_ADDRESS || '';

// The Ethereum address that holds voting power
const voterAddress = process.env.VOTER_ADDRESS || '';

// Slot index of _delegateCheckpoints in OZVotesToken (OZ v5), obtained via:
//   cd ethereum && forge inspect OZVotesToken storage-layout
const slotIndex = 9;

const POLL_INTERVAL_MS = 15_000;
const MAX_POLL_ATTEMPTS = 90;

async function pollRequestStatus(requestId: string): Promise<void> {
  for (let i = 0; i < MAX_POLL_ATTEMPTS; i++) {
    const response = await axios({
      method: 'get',
      url: `${herodotusBaseUrl}/get_queries/${requestId}`,
      headers: { accept: 'application/json', 'api-key': herodotusApiKey },
    });
    const queries: { status: string }[] = response.data.queries;
    const allCompleted = queries.every((q) => q.status === 'COMPLETED');
    const anyFailed = queries.some((q) => q.status === 'FAILED' || q.status === 'REJECTED');
    const statuses = queries.map((q) => q.status).join(', ');
    console.log(`Query statuses: [${statuses}] (attempt ${i + 1}/${MAX_POLL_ATTEMPTS})`);
    if (allCompleted) return;
    if (anyFailed) {
      throw new Error(`Herodotus query failed. Statuses: [${statuses}]`);
    }
    await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
  }
  throw new Error('Herodotus request timed out');
}

async function main() {
  const provider = new RpcProvider({ nodeUrl: starknetNetworkUrl });
  const account = new Account({
    provider,
    address: accountAddress,
    signer: accountPk,
    transactionVersion: ETransactionVersion.V3,
  });

  const { abi: spaceAbi } = await provider.getClassAt(spaceAddress);
  const space = new Contract({
    abi: spaceAbi,
    address: spaceAddress,
    providerOrAccount: provider,
  });

  const { abi: votingStrategyAbi } = await provider.getClassAt(votingStrategyAddress);
  const votingStrategyContract = new Contract({
    abi: votingStrategyAbi,
    address: votingStrategyAddress,
    providerOrAccount: provider,
  });

  const l1Token = new ethers.Contract(
    l1TokenAddress,
    ['function numCheckpoints(address account) public view returns (uint32)'],
    new ethers.JsonRpcProvider(ethNetworkUrl),
  );
  const numCheckpoints = await l1Token.numCheckpoints(voterAddress);
  console.log('numCheckpoints:', numCheckpoints);

  // Deriving the keys of the final slot in the checkpoints array for the voter and the next empty slot
  const checkpointSlotKey =
    BigInt(
      ethers.keccak256(
        ethers.keccak256(
          `0x${voterAddress.slice(2).padStart(64, '0')}${slotIndex.toString(16).padStart(64, '0')}`,
        ),
      ),
    ) +
    BigInt(numCheckpoints) -
    BigInt(1);
  const nextEmptySlotKey = checkpointSlotKey + BigInt(1);

  // ── Step 1: Create a proposal ──
  const authenticateTx = await account.execute({
    contractAddress: vanillaAuthenticatorAddress,
    entrypoint: 'authenticate',
    calldata: CallData.compile({
      target: spaceAddress,
      selector: '0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81',
      data: CallData.compile({
        author: utils.starknetEnums.getUserAddressEnum('ETHEREUM', voterAddress),
        metadataUri: ['0x1', '0x2', '0x3', '0x4'],
        executionStrategy: {
          address: '0x0000000000000000000000000000000000005678',
          params: ['0x0'],
        },
        userProposalValidationParams: [],
      }),
    }),
  });
  console.log('Authenticate transaction submitted:', authenticateTx.transaction_hash);
  await account.waitForTransaction(authenticateTx.transaction_hash);
  console.log('Proposal created successfully');

  // Get the snapshot timestamp of the proposal just created
  const proposalId = Number(await space.call('next_proposal_id', [])) - 1;
  const proposalStruct = (await space.call('proposals', [proposalId])) as any;
  const snapshotTimestamp = proposalStruct.start_timestamp;
  console.log('Proposal ID:', proposalId, 'Snapshot timestamp:', snapshotTimestamp);

  // ── Step 2: Submit Herodotus request to prove token storage root ──
  let response = await axios({
    method: 'post',
    url: `${herodotusBaseUrl}/submit-request`,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
      'api-key': herodotusApiKey,
    },
    data: {
      destination_chain_id: 'SN_SEPOLIA',
      fee: 0,
      data: {
        '11155111': {
          [`timestamp:${snapshotTimestamp}`]: {
            accounts: {
              [l1TokenAddress]: {
                props: ['STORAGE_ROOT'],
              },
            },
          },
        },
      },
    },
  });
  const requestId = response.data.request_id;
  console.log('Herodotus request submitted:', requestId);

  // ── Step 3: Poll until all queries in the request are COMPLETED ──
  await pollRequestStatus(requestId);

  // ── Step 4: Get the L1 block number from the voting strategy contract ──
  // The Herodotus batch query has now stored the timestamp→block mapping
  // in the Satellite contract. We read it via the voting strategy's exposed
  // `get_block_by_timestamp` function.
  const l1BlockNumberResult = await votingStrategyContract.call('get_block_by_timestamp', [
    snapshotTimestamp,
  ]);
  const l1BlockNumber = BigInt(l1BlockNumberResult as any);
  console.log('L1 block number:', l1BlockNumber);

  // ── Step 5: Get storage proofs from L1 ──
  response = await axios({
    method: 'post',
    url: ethNetworkUrl,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
    },
    data: {
      id: 1,
      jsonrpc: '2.0',
      method: 'eth_getProof',
      params: [
        l1TokenAddress,
        [`0x${checkpointSlotKey.toString(16)}`, `0x${nextEmptySlotKey.toString(16)}`],
        `0x${l1BlockNumber.toString(16)}`,
      ],
    },
  });

  // Convert proofs to lists of 64-bit little-endian words
  const storageProofsLittleEndianWords64 = response.data.result.storageProof.map(
    (proofWrapper: any) =>
      proofWrapper.proof.map((node: string) =>
        node
          .slice(2)
          .match(/.{1,16}/g)
          ?.map(
            (word: string) =>
              `0x${word
                .replace(/^(.(..)*)$/, '0$1')
                .match(/../g)
                ?.reverse()
                .join('')}`,
          ),
      ),
  );

  // ── Step 6: Cast Vote ──
  const voteTx = await account.execute({
    contractAddress: vanillaAuthenticatorAddress,
    entrypoint: 'authenticate',
    calldata: CallData.compile({
      target: spaceAddress,
      selector: '0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41',
      data: CallData.compile({
        voter: utils.starknetEnums.getUserAddressEnum('ETHEREUM', voterAddress),
        proposalId: cairo.uint256(proposalId),
        choice: '0x1',
        user_voting_strategies: [
          {
            index: '0x0',
            params: CallData.compile({
              checkpoint_index: numCheckpoints - BigInt(1),
              checkpoint_mpt_proof: storageProofsLittleEndianWords64[0],
              exclusion_mpt_proof: storageProofsLittleEndianWords64[1],
            }),
          },
        ],
        metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      }),
    }),
  });
  console.log('Vote transaction submitted:', voteTx.transaction_hash);
  await account.waitForTransaction(voteTx.transaction_hash);
  console.log('Vote cast successfully');
}

main();
