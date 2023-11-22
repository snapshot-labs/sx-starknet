import fs from 'fs';
import {
  defaultProvider,
  Provider,
  RpcProvider,
  Account,
  ec,
  json,
  CallData,
  constants,
  shortString,
  cairo,
  CairoCustomEnum,
  Contract,
  CairoOption,
  CairoOptionVariant,
} from 'starknet';
import { ethers } from 'ethers';
import axios from 'axios';

export function getUserAddressEnum(type: 'ETHEREUM' | 'STARKNET' | 'CUSTOM', address: string) {
  return new CairoCustomEnum({
    Starknet: type === 'STARKNET' ? address : undefined,
    Ethereum: type === 'ETHEREUM' ? address : undefined,
    Custom: type === 'CUSTOM' ? address : undefined,
  });
}

export function getChoiceEnum(choice: 0 | 1 | 2) {
  return new CairoCustomEnum({
    Against: choice === 0 ? 0 : undefined,
    For: choice === 1 ? 1 : undefined,
    Abstain: choice === 2 ? 2 : undefined,
  });
}

async function main() {
  const account_address = '0x0071399180e89305007c030004d68ebbed03e2b6d780de66ba36c64630acca52';
  const account_pk = '0x2587FB9D2FE799E759769D7DB115018C4FDF8F0F4047AE5E0A6C17B56B8B224';
  const network = 'https://starknet-testnet.public.blastapi.io/rpc/v0.5';
  const provider = new RpcProvider({ nodeUrl: network });
  const account = new Account(provider, account_address, account_pk);

  const spaceAddress = '0x02b9ac7cb47a57ca4144fd0da74203bc8c4aaf411f438b08770bac3680a066cb';
  const vanillaAuthenticatorAddress =
    '0x6fa12cffc11ba775ccf99bad7249f06ec5fc605d002716b2f5c7f5561d28081';
  const evmSlotValueVotingStrategyAddress =
    '0x07e95f740a049896784969d61389f119291a2de37186f7cfa8ba9d2f3037b32a';

  const l1TokenAddress = '0xd96844c9B21CB6cCf2c236257c7fc703E43BA071'; //OZ token 18 decimals
  const slotIndex = 0;
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

  // There is a util in sx.js to do this
  const slotKey = ethers.utils.keccak256(
    `0x${voterAddress.slice(2).padStart(64, '0')}${slotIndex.toString(16).padStart(64, '0')}`,
  );

  // Create a proposal
  // const result = await account.execute({
  //   contractAddress: vanillaAuthenticatorAddress,
  //   entrypoint: 'authenticate',
  //   calldata: CallData.compile({
  //     target: spaceAddress,
  //     selector: '0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81',
  //     data: CallData.compile({
  //       author: getUserAddressEnum('ETHEREUM', voterAddress),
  //       metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //       executionStrategy: {
  //         address: '0x0000000000000000000000000000000000005678',
  //         params: ['0x0'],
  //       },
  //       userProposalValidationParams: [],
  //     }),
  //   }),
  // });

  // console.log(result);

  // Get the snapshot timestamp of the proposal just created
  const proposalId = Number(await space.call('next_proposal_id', [])) - 1;
  const proposalStruct = (await space.call('proposals', [proposalId])) as any;
  console.log(proposalStruct);
  const snapshotTimestamp = proposalStruct.start_timestamp;

  // Proving the token storage root of the token at the snapshot timestamp
  // await axios({
  //   method: 'post',
  //   url: 'https://api.herodotus.cloud/submit-batch-query?apiKey=87cad02e-2db0-412f-b469-b46ffa19bc75',
  //   headers: {
  //     accept: 'application/json',
  //     'content-type': 'application/json',
  //   },
  //   data: {
  //     destinationChainId: 'SN_GOERLI',
  //     fee: '0',
  //     data: {
  //       '5': {
  //         [`${'timestamp:'}${snapshotTimestamp}`]: {
  //           accounts: {
  //             [l1TokenAddress]: {
  //               props: ['STORAGE_ROOT'],
  //             },
  //             "vitalik.eth": {
  //               "props": ["BALANCE", "NONCE", "STORAGE_ROOT"],
  //             }
  //           },
  //         },
  //       },
  //     },
  //     webhook: {
  //       url: 'https://webhook.site/1f3a9b5d-5c8c-4e2a-9d7e-6c3c5a0a0e2f',
  //       headers: {
  //         'Content-Type': 'application/json',
  //       },
  //     },
  //   },
  // })
  //   .then(function (response) {
  //     console.log(response.data);
  //   })
  //   .catch(function (error) {
  //     console.log(error);
  //   });

  console.log(snapshotTimestamp);
  // Get the binary search tree to remap the snapshot timestamp to the L1 block number
  const response = await axios({
    method: 'get',
    url: `${'https://ds-indexer.api.herodotus.cloud/binsearch-path?timestamp='}${snapshotTimestamp}${'&deployed_on_chain=SN_GOERLI&accumulates_chain=5'}`,
    headers: {
      accept: 'application/json',
    },
  });

  console.log(response.data);

  // type ProofElement = {
  //   index: number;
  //   value: string;
  //   proof: string[];
  // };


  // const { abi: evmSlotValueVotingStrategyAbi } = await provider.getClassAt(
  //   evmSlotValueVotingStrategyAddress,
  // );
  // const evmSlotValueVotingStrategy = new Contract(
  //   evmSlotValueVotingStrategyAbi,
  //   evmSlotValueVotingStrategyAddress,
  //   provider,
  // );


  // console.log(CallData.compile({
  //   timestamp: 1688044344,
  //   tree: {
  //     mapped_id: response.data.remapper.onchainRemapperId,
  //     last_pos: 1,
  //     peaks: [response.data.proofs[0].peaksHashes[0]],
  //     proofs: [{ index: 1, value: cairo.uint256(response.data.proofs[0].peaksHashes[0]), proof: [] }],
  //     left_neighbor: new CairoOption<ProofElement>(CairoOptionVariant.None),
  //   },
  // }));

  // // cache block number in single slot proof voting strategy
  // await account.execute({
  //   contractAddress: evmSlotValueVotingStrategyAddress,
  //   entrypoint: 'cache_timestamp',
  //   calldata: CallData.compile({
  //     timestamp: 1700583144,
  //     tree: {
  //       mapped_id: response.data.remapper.onchainRemapperId,
  //       last_pos: 1,
  //       peaks: [response.data.proofs[0].peaksHashes[0]],
  //       proofs: [{ index: 1, value: cairo.uint256(response.data.proofs[0].peaksHashes[0]), proof: [] }],
  //       left_neighbor: new CairoOption<ProofElement>(CairoOptionVariant.None),
  //     },
  //   }),
  // });


  // const l1BlockNumber = 'latest';

  // // Cast vote
  // const response = await axios({
  //   method: 'post',
  //   url: 'https://eth-goerli.g.alchemy.com/v2/0wkBfjpc150LmkMBN7fcsXXlgqHx-GjP',
  //   headers: {
  //     accept: 'application/json',
  //     'content-type': 'application/json',
  //   },
  //   data: {
  //     id: 1,
  //     jsonrpc: '2.0',
  //     method: 'eth_getProof',
  //     params: [l1TokenAddress, [slotKey], l1BlockNumber],
  //   },
  // });

  // const storageProofLittleEndianWords64 = response.data.result.storageProof[0].proof.map(
  //   (node: string) =>
  //     node
  //       .slice(2)
  //       .match(/.{1,16}/g)
  //       ?.map(
  //         (word: string) =>
  //           `0x${word
  //             .replace(/^(.(..)*)$/, '0$1')
  //             .match(/../g)
  //             ?.reverse()
  //             .join('')}`,
  //       ),
  // );
  // console.log(storageProofLittleEndianWords64);
  // console.log(proposalId);

  // await account.execute({
  //   contractAddress: vanillaAuthenticatorAddress,
  //   entrypoint: 'authenticate',
  //   calldata: CallData.compile({
  //     target: spaceAddress,
  //     selector: '0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41',
  //     data: CallData.compile({
  //       voter: getUserAddressEnum('ETHEREUM', voterAddress),
  //       proposalId: cairo.uint256(proposalId),
  //       choice: '0x1',
  //       user_voting_strategies: [
  //         {
  //           index: '0x0',
  //           params: CallData.compile({
  //             storageProof: storageProofLittleEndianWords64,
  //           }),
  //         },
  //       ],
  //       metadataUri: ['0x1', '0x2', '0x3', '0x4'],
  //     }),
  //   }),
  // });

  // console.log(storageProofLittleEndianWords64);
}

main();
