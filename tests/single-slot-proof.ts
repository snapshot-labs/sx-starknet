import dotenv from 'dotenv';
import axios from 'axios';
import { ethers } from 'ethers';
import {
  RpcProvider,
  Account,
  CallData,
  cairo,
  Contract,
  CairoOption,
  CairoOptionVariant,
} from 'starknet';
import { utils } from '@snapshot-labs/sx';

dotenv.config();

type ProofElement = {
  index: number;
  value: string;
  proof: string[];
};

const accountAddress = process.env.ADDRESS || '';
const accountPk = process.env.PK || '';
const starknetNetworkUrl = process.env.STARKNET_NETWORK_URL || '';
const ethNetworkUrl = process.env.ETH_NETWORK_URL || '';
const herodotusApiKey = process.env.HERODOTUS_API_KEY || '';

async function main() {
  const provider = new RpcProvider({ nodeUrl: starknetNetworkUrl });
  const account = new Account(provider, accountAddress, accountPk);

  const spaceAddress = '0x040e53631973b92651746b4905655b0d797323fd2f47eb80cf6fad521a5ac87d';
  const vanillaAuthenticatorAddress =
    '0x6fa12cffc11ba775ccf99bad7249f06ec5fc605d002716b2f5c7f5561d28081';
  const evmSlotValueVotingStrategyAddress =
    '0x06cf32ad42d1c6ee98758b00c6a7c7f293d9efb30f2afea370019a88f8e252be';

  const l1TokenAddress = '0xd96844c9B21CB6cCf2c236257c7fc703E43BA071'; //OZ token 18 decimals
  const slotIndex = 0; // Slot index of the balances mapping in the token contract
  const voterAddress = '0x2842c82E20ab600F443646e1BC8550B44a513D82';

  const { abi: spaceAbi } = await provider.getClassAt(spaceAddress);
  const space = new Contract(spaceAbi, spaceAddress, provider);

  const { abi: vanillaAuthenticatorAbi } = await provider.getClassAt(vanillaAuthenticatorAddress);
  const vanillaAuthenticator = new Contract(
    vanillaAuthenticatorAbi,
    vanillaAuthenticatorAddress,
    provider,
  );
  vanillaAuthenticator.connect(account);

  const slotKey = ethers.utils.keccak256(
    `0x${voterAddress.slice(2).padStart(64, '0')}${slotIndex.toString(16).padStart(64, '0')}`,
  );
  let response;

  // Create a proposal
  await account.execute({
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

  // Get the snapshot timestamp of the proposal just created
  const proposalId = Number(await space.call('next_proposal_id', [])) - 1;
  const proposalStruct = (await space.call('proposals', [proposalId])) as any;
  const snapshotTimestamp = proposalStruct.start_timestamp;

  // Proving the token storage root of the token at the snapshot timestamp
  // Webhook here is just a random address, can update
  response = await axios({
    method: 'post',
    url: 'https://api.herodotus.cloud/submit-batch-query?apiKey=' + herodotusApiKey,
    headers: {
      accept: 'application/json',
      'content-type': 'application/json',
    },
    data: {
      destinationChainId: 'SN_GOERLI',
      fee: '0',
      data: {
        '5': {
          [`${'timestamp:'}${snapshotTimestamp}`]: {
            accounts: {
              [l1TokenAddress]: {
                props: ['STORAGE_ROOT'],
              },
            },
          },
        },
      },
      webhook: {
        url: 'https://webhook.site/1f3a9b5d-5c8c-4e2a-9d7e-6c3c5a0a0e2f',
        headers: {
          'Content-Type': 'application/json',
        },
      },
    },
  });
  console.log(response.data);

  // Wait for the query to be processed. This will return a query status of DONE when it's ready
  // Webhooks can be used to get notified when the query is ready.
  response = await axios({
    method: 'get',
    url:
      'https://api.herodotus.cloud/batch-query-status?apiKey=' +
      herodotusApiKey +
      '&batchQueryId=' +
      response.data.internalId,
    headers: {
      accept: 'application/json',
    },
  });
  console.log(response.data);

  // Get the binary search tree to remap the snapshot timestamp to the L1 block number
  response = await axios({
    method: 'get',
    url:
      'https://ds-indexer.api.herodotus.cloud/binsearch-path?timestamp=' +
      snapshotTimestamp +
      '&deployed_on_chain=SN_GOERLI&accumulates_chain=5',
    headers: {
      accept: 'application/json',
    },
  });

  // This is the snapshot L1 block number
  const l1BlockNumber = response.data.path[1].blockNumber;

  // cache block number in single slot proof voting strategy
  await account.execute({
    contractAddress: evmSlotValueVotingStrategyAddress,
    entrypoint: 'cache_timestamp',
    calldata: CallData.compile({
      timestamp: snapshotTimestamp,
      tree: {
        mapped_id: response.data.remapper.onchainRemapperId,
        last_pos: 3,
        peaks: response.data.proofs[0].peaksHashes,
        proofs: response.data.proofs.map((proof: any) => {
          return {
            index: proof.elementIndex,
            value: cairo.uint256(proof.elementHash),
            proof: proof.siblingsHashes,
          };
        }),
        left_neighbor: new CairoOption<ProofElement>(CairoOptionVariant.None),
      },
    }),
  });

  // Query the node for the storage proof of the desired slot at the snapshot L1 block number
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
      params: [l1TokenAddress, [slotKey], `0x${l1BlockNumber.toString(16)}`],
    },
  });

  // This takes the proof from the response and converts it to a list of 64 bit little endian words
  const storageProofLittleEndianWords64 = response.data.result.storageProof[0].proof.map(
    (node: string) =>
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
  );

  // Cast Vote
  await account.execute({
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
              storageProof: storageProofLittleEndianWords64,
            }),
          },
        ],
        metadataUri: ['0x1', '0x2', '0x3', '0x4'],
      }),
    }),
  });
}

main();
