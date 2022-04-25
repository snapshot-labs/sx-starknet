// import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
// import { expect } from 'chai';
// import { Contract, ContractFactory } from 'ethers';
// import { starknet, network, ethers } from 'hardhat';
// import { FOR, SplitUint256 } from '../starknet/shared/types';
// import { StarknetContractFactory, StarknetContract, HttpNetworkConfig } from 'hardhat/types';
// import { stark } from 'starknet';
// import { strToShortStringArr } from '@snapshot-labs/sx';
// import { _TypedDataEncoder } from '@ethersproject/hash';
// import { EIP712_TYPES } from '../ethereum/shared/utils';
// import {
//   VITALIK_ADDRESS,
//   VITALIK_STRING_ADDRESS,
//   vanillaSetup,
//   EXECUTE_METHOD,
//   PROPOSAL_METHOD,
//   VOTE_METHOD,
//   VITALIK_ADDRESS2,
//   VITALIK_ADDRESS3,
// } from '../starknet/shared/setup';
// import { expectAddressEquality } from '../starknet/shared/helpers';

// const { getSelectorFromName } = stark;

// // Dummy tx
// const tx1 = {
//   to: VITALIK_STRING_ADDRESS,
//   value: 1,
//   data: '0x12',
//   operation: 0,
//   nonce: 0,
// };

// // Dummy tx 2
// const tx2 = {
//   to: VITALIK_STRING_ADDRESS,
//   value: 2,
//   data: '0x34',
//   operation: 0,
//   nonce: 1,
// };

// /**
//  * Utility function that returns an example executionHash and `txHashes`, given a verifying contract.
//  * @param _verifyingContract The verifying l1 contract
//  * @returns
//  */
// function createExecutionHash(_verifyingContract: string): {
//   executionHash: SplitUint256;
//   txHashes: Array<string>;
// } {
//   const domain = {
//     chainId: ethers.BigNumber.from(1), //TODO: should be network.config.chainId but it's not working
//     verifyingContract: _verifyingContract,
//   };

//   // 2 transactions in proposal
//   const txHash1 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx1);
//   const txHash2 = _TypedDataEncoder.hash(domain, EIP712_TYPES, tx2);

//   const abiCoder = new ethers.utils.AbiCoder();
//   const hash = BigInt(ethers.utils.keccak256(abiCoder.encode(['bytes32[]'], [[txHash1, txHash2]])));

//   const executionHash = SplitUint256.fromUint(hash);
//   return {
//     executionHash,
//     txHashes: [txHash1, txHash2],
//   };
// }

// describe('Create proposal, cast vote, and send execution to l1', function () {
//   this.timeout(12000000);
//   const networkUrl: string = (network.config as HttpNetworkConfig).url;
//   let L2contractFactory: StarknetContractFactory;
//   let l1ExecutorFactory: ContractFactory;
//   let MockStarknetMessaging: ContractFactory;
//   let mockStarknetMessaging: Contract;
//   let l1Executor: Contract;
//   let signer: SignerWithAddress;
//   let spaceContract: StarknetContract;
//   let authContract: StarknetContract;
//   let votingContract: StarknetContract;
//   let zodiacRelayer: StarknetContract;

//   before(async function () {
//     this.timeout(800000);

//     L2contractFactory = await starknet.getContractFactory('./contracts/starknet/space/space.cairo');

//     ({
//       vanillaSpace: spaceContract,
//       vanillaAuthenticator: authContract,
//       vanillaVotingStrategy: votingContract,
//       zodiacRelayer,
//     } = await vanillaSetup());

//     const signers = await ethers.getSigners();
//     signer = signers[0];

//     MockStarknetMessaging = (await ethers.getContractFactory(
//       'MockStarknetMessaging',
//       signer
//     )) as ContractFactory;
//     mockStarknetMessaging = await MockStarknetMessaging.deploy();
//     await mockStarknetMessaging.deployed();

//     const owner = signer.address;
//     const avatar = signer.address; // Dummy
//     const target = signer.address; // Dummy
//     const starknetCore = mockStarknetMessaging.address;
//     const relayer = BigInt(zodiacRelayer.address);
//     l1ExecutorFactory = await ethers.getContractFactory('SafeX', signer);
//     l1Executor = await l1ExecutorFactory.deploy(starknetCore, relayer);
//     await l1Executor.deployed();
//   });

//   it('should deploy the messaging contract', async () => {
//     const { address: deployedTo, l1_provider: L1Provider } =
//       await starknet.devnet.loadL1MessagingContract(networkUrl);

//     expect(deployedTo).not.to.be.undefined;
//     expect(L1Provider).to.equal(networkUrl);
//   });

//   it('should load the already deployed contract if the address is provided', async () => {
//     const { address: loadedFrom } = await starknet.devnet.loadL1MessagingContract(
//       networkUrl,
//       mockStarknetMessaging.address
//     );

//     expect(mockStarknetMessaging.address).to.equal(loadedFrom);
//   });

//   it('should correctly receive and accept a finalized proposal on l1', async () => {
//     this.timeout(1200000);
//     const { executionHash, txHashes } = createExecutionHash(l1Executor.address);
//     const metadata_uri = strToShortStringArr(
//       'Hello and welcome to Snapshot X. This is the future of governance.'
//     );
//     const proposer_address = VITALIK_ADDRESS;
//     const proposal_id = BigInt(1);
//     const voting_params: Array<bigint> = [];
//     const eth_block_number = BigInt(1337);
//     const execution_params: Array<bigint> = [BigInt(l1Executor.address)];
//     const calldata = [
//       proposer_address,
//       executionHash.low,
//       executionHash.high,
//       BigInt(metadata_uri.length),
//       ...metadata_uri,
//       eth_block_number,
//       BigInt(voting_params.length),
//       ...voting_params,
//       BigInt(execution_params.length),
//       execution_params,
//     ];

//     // -- Creates a proposal --
//     await authContract.invoke(EXECUTE_METHOD, {
//       to: BigInt(spaceContract.address),
//       function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
//       calldata,
//     });
//     console.log("Proposal created");

//     // -- Casts a vote FOR 1/3 --
//     {
//       const voter_address = proposer_address;
//       const votingParams: Array<BigInt> = [];
//       await authContract.invoke(EXECUTE_METHOD, {
//         to: BigInt(spaceContract.address),
//         function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
//         calldata: [voter_address, proposal_id, BigInt(votingParams.length), ...votingParams],
//       });
//       console.log("1/3");
//     }

//     // -- Casts a vote FOR 2/3--
//     {
//       const votingParams: Array<BigInt> = [];
//       await authContract.invoke(EXECUTE_METHOD, {
//         to: BigInt(spaceContract.address),
//         function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
//         calldata: [VITALIK_ADDRESS2, proposal_id, BigInt(votingParams.length), ...votingParams],
//       });
//       console.log("2/3");
//     }

//     // -- Casts a vote FOR 3/3--
//     {
//       const voter_address = proposer_address;
//       const votingParams: Array<BigInt> = [];
//       await authContract.invoke(EXECUTE_METHOD, {
//         to: BigInt(spaceContract.address),
//         function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
//         calldata: [VITALIK_ADDRESS3, proposal_id, BigInt(votingParams.length), ...votingParams],
//       });
//       console.log("3/3");
//     }

//     // -- Load messaging contract
//     {
//       await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);
//     }

//     // -- Finalize proposal and send execution hash to L1 --
//     {
//       await spaceContract.invoke('finalize_proposal', {
//         proposal_id: proposal_id,
//         execution_params: [BigInt(l1Executor.address)],
//       });
//     }

//     // --  Flush messages and check that communication went well --
//     {
//       const flushL2Response = await starknet.devnet.flush();
//       expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
//       const flushL2Messages = flushL2Response.consumed_messages.from_l2;

//       expect(flushL2Messages).to.have.a.lengthOf(1);
//       expectAddressEquality(flushL2Messages[0].from_address, zodiacRelayer.address);
//       expectAddressEquality(flushL2Messages[0].to_address, l1Executor.address);
//     }

//     // Check that l1 can receive the proposal correctly
//     {
//       const proposalOutcome = BigInt(1);

//       const callerAddress = BigInt(spaceContract.address);


//       // [tx1.to, tx2.to],
//       // [tx1.value, tx2.value],
//       // [tx1.data, tx2.data],
//       // [tx1.operation, tx1.operation]

//       // Check that it works when provided correct parameters.
//       console.log(callerAddress, 1, executionHash.low, executionHash.high)
//       await l1Executor.executeTxs(
//         callerAddress,
//         1,
//         executionHash.low,
//         executionHash.high,
//       );
//     }

//   });
// });
