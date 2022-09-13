import fs from 'fs';
import { defaultProvider, Account, ec, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {
  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const modules = JSON.parse(fs.readFileSync('./deployments/modules.json').toString());

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
  const controllerAddress = '0x0764c647e4c5f6e81c5baa1769b4554e44851a7b6319791fc6db9e25a32148bb'; // Controller address is orlando's argent x

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

  // Deploy spaces through space factory.typ
  const { transaction_hash: txHash } = await starkAccount.execute(
    [
      {
        contractAddress: spaceFactoryAddress,
        entrypoint: 'deploy_space',
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
          votingStrategyParamsFlat1.length,
          ...votingStrategyParamsFlat1,
          votingStrategies1.length,
          ...votingStrategies1,
          authenticators1.length,
          ...authenticators1,
          executors.length,
          ...executors,
        ],
      },
      {
        contractAddress: spaceFactoryAddress,
        entrypoint: 'deploy_space',
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
          votingStrategyParamsFlat2.length,
          ...votingStrategyParamsFlat2,
          votingStrategies2.length,
          ...votingStrategies2,
          authenticators2.length,
          ...authenticators2,
          executors.length,
          ...executors,
        ],
      },
      {
        contractAddress: spaceFactoryAddress,
        entrypoint: 'deploy_space',
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
          votingStrategyParamsFlat3.length,
          ...votingStrategyParamsFlat3,
          votingStrategies3.length,
          ...votingStrategies3,
          authenticators3.length,
          ...authenticators3,
          executors.length,
          ...executors,
        ],
      },
    ],
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log('waiting for spaces to be deployed, transaction hash: ', txHash);
  await defaultProvider.waitForTransaction(txHash);

  // Extracting space address from the event emitted by the space factory.
  const receipt = (await defaultProvider.getTransactionReceipt(txHash)) as any;
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
  fs.writeFileSync('./deployments/goerli3.json', JSON.stringify(deployments));
  console.log('---- DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
