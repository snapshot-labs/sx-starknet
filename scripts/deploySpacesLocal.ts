import fs from 'fs';
import { Provider, defaultProvider, Account, ec, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {

  const provider = new Provider({
    sequencer: {
      baseUrl: 'http://127.0.0.1:8000/',
      feederGatewayUrl: 'feeder_gateway',
      gatewayUrl: 'gateway',
    }, // Similar to arguements used in docs
  });

  const starkAccount = new Account(
    provider,
    '0x68fd97768680005ceeb5206be5a7d242b41c6e6307f921935b85548bb976498',
    ec.getKeyPair('0x430804b5f3870ab9d7cd07b434255648')
  );
  const modules = JSON.parse(fs.readFileSync('./deployments/modules2.json').toString());

  const vanillaAuthenticatorAddress = modules.authenticators.vanilla;
  const ethSigAuthenticatorAddress = modules.authenticators.ethSig;
  const vanillaVotingStrategyAddress = modules.votingStrategies.vanilla;
  const ethBalanceOfVotingStrategyAddress = modules.votingStrategies.ethBalanceOf.address;
  const vanillaExecutionStrategyAddress = modules.executionStrategies.vanilla;
  const zodiacExecutionStrategyAddress = modules.executionStrategies.zodiac;
  const spaceFactoryAddress = modules.spaceFactory.address;
  const spaceClassHash = modules.spaceFactory.spaceClassHash;

  const votingDelay = 0;
  const minVotingDuration = 0;
  const maxVotingDuration = 200000;
  const executors = [vanillaExecutionStrategyAddress, zodiacExecutionStrategyAddress];
  const quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const proposalThreshold = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const controllerAddress = '0x68fd97768680005ceeb5206be5a7d242b41c6e6307f921935b85548bb976498'; 
  // const controllerAddress = '0x1f019daad09f101dec4ef7f50bc67202d88905c75a2a1545ce96e9fbee79a78'; 

  // Vanilla Auth + Vanilla Voting
  const votingStrategies1 = [vanillaVotingStrategyAddress];
  const votingStrategyParams1 = [[]];
  const votingStrategyParamsFlat1 = utils.encoding.flatten2DArray(votingStrategyParams1);
  const authenticators1 = [vanillaAuthenticatorAddress];

  // EthSig Auth + Vanilla Voting
  const votingStrategies2 = [vanillaVotingStrategyAddress];
  const votingStrategyParams2 = [[]];
  const votingStrategyParamsFlat2 = utils.encoding.flatten2DArray(votingStrategyParams2);
  const authenticators2 = [ethSigAuthenticatorAddress];

  // EthSig Auth + EthBalanceOf Voting
  const votingStrategies3 = [ethBalanceOfVotingStrategyAddress];
  const votingStrategyParams3 = [['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3']];
  const votingStrategyParamsFlat3 = utils.encoding.flatten2DArray(votingStrategyParams3);
  const authenticators3 = [ethSigAuthenticatorAddress];

  const metadataUri = utils.strings.strToShortStringArr('SnapshotXTestSpace');

  // Deploy spaces through space factory.typ
  const { transaction_hash: txHash } = await starkAccount.execute(
    [
      {
        contractAddress: spaceFactoryAddress,
        entrypoint: 'deploySpace',
        calldata: [
          controllerAddress,
          votingDelay,
          minVotingDuration,
          maxVotingDuration,
          proposalThreshold.low,
          proposalThreshold.high,
          controllerAddress,
          quorum.low,
          quorum.high,
          votingStrategies1.length,
          ...votingStrategies1,
          votingStrategyParamsFlat1.length,
          ...votingStrategyParamsFlat1,
          authenticators1.length,
          ...authenticators1,
          executors.length,
          ...executors,
          metadataUri.length,
          ...metadataUri,
        ],
      },
      {
        contractAddress: spaceFactoryAddress,
        entrypoint: 'deploySpace',
        calldata: [
          controllerAddress,
          votingDelay,
          minVotingDuration,
          maxVotingDuration,
          proposalThreshold.low,
          proposalThreshold.high,
          controllerAddress,
          quorum.low,
          quorum.high,
          votingStrategies2.length,
          ...votingStrategies2,
          votingStrategyParamsFlat2.length,
          ...votingStrategyParamsFlat2,
          authenticators2.length,
          ...authenticators2,
          executors.length,
          ...executors,
          metadataUri.length,
          ...metadataUri,
        ],
      },
      {
        contractAddress: spaceFactoryAddress,
        entrypoint: 'deploySpace',
        calldata: [
          controllerAddress,
          votingDelay,
          minVotingDuration,
          maxVotingDuration,
          proposalThreshold.low,
          proposalThreshold.high,
          controllerAddress,
          quorum.low,
          quorum.high,
          votingStrategies3.length,
          ...votingStrategies3,
          votingStrategyParamsFlat3.length,
          ...votingStrategyParamsFlat3,
          authenticators3.length,
          ...authenticators3,
          executors.length,
          ...executors,
          metadataUri.length,
          ...metadataUri,
        ],
      },
    ],
    undefined,
    { maxFee: '558180000000000000' }
  );
  console.log('waiting for spaces to be deployed, transaction hash: ', txHash);
  await provider.waitForTransaction(txHash);

  // Extracting space address from the event emitted by the space factory.
  const receipt = (await provider.getTransactionReceipt(txHash)) as any;
  // The events corresponding to the deployment events are at indexes 1, 3, 5 for the 3 spaces
  // The addresses of the space contracts are stored at the 1st index of the event array
  const spaceAddress1 = receipt.events[1].data[1];
  const spaceAddress2 = receipt.events[3].data[1];
  const spaceAddress3 = receipt.events[5].data[1];

  // Storing deployment config.
  const deployments = {
    spaceFactory: {
      address: spaceFactoryAddress,
      spaceClassHash: spaceClassHash,
    },
    spaces: [
      {
        name: 'Vanilla Auth + Vanilla Voting',
        address: spaceAddress1,
        controller: controllerAddress,
        minVotingDuration: minVotingDuration,
        maxVotingDuration: maxVotingDuration,
        proposalThreshold: proposalThreshold.toHex(),
        quorum: quorum.toHex(),
        authenticators: {
          vanilla: vanillaAuthenticatorAddress,
        },
        votingStrategies: {
          vanilla: {
            index: 0,
            address: vanillaVotingStrategyAddress,
            parameters: [],
          },
        },
        executionStrategies: {
          vanilla: vanillaExecutionStrategyAddress,
          zodiac: zodiacExecutionStrategyAddress,
        },
      },
      {
        name: 'EthSig Auth + Vanilla Voting',
        address: spaceAddress2,
        controller: controllerAddress,
        minVotingDuration: minVotingDuration,
        maxVotingDuration: maxVotingDuration,
        proposalThreshold: proposalThreshold.toHex(),
        quorum: quorum.toHex(),
        authenticators: {
          ethSig: ethSigAuthenticatorAddress,
        },
        votingStrategies: {
          vanilla: {
            index: 0,
            address: vanillaVotingStrategyAddress,
            parameters: [],
          },
        },
        executionStrategies: {
          vanilla: vanillaExecutionStrategyAddress,
          zodiac: zodiacExecutionStrategyAddress,
        },
      },
      {
        name: 'EthSig Auth + EthBalanceOf Voting',
        address: spaceAddress3,
        controller: controllerAddress,
        minVotingDuration: minVotingDuration,
        maxVotingDuration: maxVotingDuration,
        proposalThreshold: proposalThreshold.toHex(),
        quorum: quorum.toHex(),
        authenticators: {
          ethSig: ethSigAuthenticatorAddress,
        },
        votingStrategies: {
          ethBalanceOf: {
            index: 0,
            address: ethBalanceOfVotingStrategyAddress,
            parameters: ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3'],
          },
        },
        executionStrategies: {
          vanilla: vanillaExecutionStrategyAddress,
          zodiac: zodiacExecutionStrategyAddress,
        },
      },
    ],
  };
  fs.writeFileSync('./deployments/goerli5.json', JSON.stringify(deployments));
  console.log('---- DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
