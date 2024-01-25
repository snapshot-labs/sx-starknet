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
  shortString,
} from 'starknet';
import { utils } from '@snapshot-labs/sx';
import { voteTypes, Vote } from '../tests/eth-sig-types';

dotenv.config();

type ProofElement = {
  index: number;
  value: string;
  proof: string[];
};

function getRSVFromSig(sig: string) {
  if (sig.startsWith('0x')) {
    sig = sig.substring(2);
  }
  const r = `0x${sig.substring(0, 64)}`;
  const s = `0x${sig.substring(64, 64 * 2)}`;
  const v = `0x${sig.substring(64 * 2)}`;
  return { r, s, v };
}

const accountAddress = process.env.ADDRESS || '';
const accountPk = process.env.PK || '';
const ethPk = process.env.ETH_PK || '';
const starknetNetworkUrl = process.env.STARKNET_NETWORK_URL || '';
const ethNetworkUrl = process.env.ETH_NETWORK_URL || '';
const herodotusApiKey = process.env.HERODOTUS_API_KEY || '';

async function main() {
  const provider = new RpcProvider({ nodeUrl: starknetNetworkUrl });
  const account = new Account(provider, accountAddress, accountPk);

  const spaceAddress = '0x154d44960097ab0373a349f182ccde27dba99507b908146fd5a3f2e2bdabd7';
  const vanillaAuthenticatorAddress =
    '0x00c4b0a7d8626638e7dd410b16ccbc48fe36e68f864dec75b23ef41e3732d5d2';
  const ethSigAuthenticatorAddress =
    '0x00b610082a0f39458e03a96663767ec25d6fb259f32c1e0dd19bf2be7a52532c';
  const OZVotesStorageProofVotingStrategy =
    '0x6b66f8e377a8879e8ac48cb0a4e368e8eac2dd4edae2f5d1621080f3fcfcc16';

  // OZ Votes token 18 decimals
  const l1TokenAddress = '0x7421B0f131c32876c0eF305F9e4B2591bfbFF472';
  // Slot index of the checkpoints mapping in the token contract,
  //obtained using Foundry's Cast Storage Layout tool.
  const slotIndex = 8;

  const voterAddress = '0x02c7BFfEDBBaFa1244dBDd5338b303e7DeD4115D';

  const { abi: spaceAbi } = await provider.getClassAt(spaceAddress);
  const space = new Contract(spaceAbi, spaceAddress, provider);

  const { abi: vanillaAuthenticatorAbi } = await provider.getClassAt(vanillaAuthenticatorAddress);
  const vanillaAuthenticator = new Contract(
    vanillaAuthenticatorAbi,
    vanillaAuthenticatorAddress,
    provider,
  );
  vanillaAuthenticator.connect(account);

  const l1Token = new ethers.Contract(
    l1TokenAddress,
    ['function numCheckpoints(address account) public view returns (uint256)'],
    new ethers.JsonRpcProvider(ethNetworkUrl),
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
  console.log(snapshotTimestamp);

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
      destinationChainId: 'STARKNET',
      fee: '900719925474099',
      data: {
        '1': {
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
      '&deployed_on_chain=STARKNET&accumulates_chain=1',
    headers: {
      accept: 'application/json',
    },
  });

  // This is the snapshot L1 block number
  const l1BlockNumber = response.data.path[1].blockNumber;
  console.log(l1BlockNumber);

  // cache block number in voting strategy
  await account.execute({
    contractAddress: OZVotesStorageProofVotingStrategy,
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

  // Need to query the state of the checkpoints array at the snapshot block number
  const numCheckpoints = await l1Token.numCheckpoints(voterAddress, { blockTag: l1BlockNumber });
  console.log(numCheckpoints);

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

  // Query the node for the storage proofs of the 2 slots at the snapshot block number
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

  // This takes the proofs from the response and converts them to a list of 64 bit little endian words
  const storageProofsLittleEndianWords64 = response.data.result.storageProof.map(
    (proofWrapper: any) =>
      proofWrapper.proof.map(
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
      ),
  );

  // Cast Vote via vanilla authenticator
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

  // Cast vote via ethSigAuthenticator
  let signer = new ethers.Wallet(ethPk);
  const voteMsg: Vote = {
    chainId: shortString.encodeShortString('SN_MAIN'),
    authenticator: ethSigAuthenticatorAddress,
    space: spaceAddress,
    voter: signer.address,
    proposalId: `0x${proposalId.toString(16)}`,
    choice: '0x1',
    userVotingStrategies: [
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
  };
  let sig = await signer.signTypedData({}, voteTypes, voteMsg);
  let splitSig = getRSVFromSig(sig);

  await account.execute({
    contractAddress: ethSigAuthenticatorAddress,
    entrypoint: 'authenticate_vote',
    calldata: CallData.compile({
      r: cairo.uint256(splitSig.r),
      s: cairo.uint256(splitSig.s),
      v: splitSig.v,
      space: voteMsg.space,
      voter: voteMsg.voter,
      proposalId: cairo.uint256(voteMsg.proposalId),
      choice: voteMsg.choice,
      userVotingStrategies: voteMsg.userVotingStrategies,
      metadataUri: voteMsg.metadataUri,
    }),
  });
}

main();
