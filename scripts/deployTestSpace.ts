import fs from 'fs';
import { defaultProvider, json } from 'starknet';
import { SplitUint256 } from '../test/shared/types';
import { flatten2DArray } from '../test/shared/helpers';

async function main() {
  const compiledVanillaAuthenticator = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/Authenticators/Vanilla.cairo/Vanilla.json'
      )
      .toString('ascii')
  );
  const compiledStarkTxAuthenticator = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/Authenticators/StarkTx.cairo/StarkTx.json'
      )
      .toString('ascii')
  );
  const compiledVanillaVotingStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/VotingStrategies/Vanilla.cairo/Vanilla.json'
      )
      .toString('ascii')
  );
  const compiledSingleSlotProofVotingStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/VotingStrategies/SingleSlotProof.cairo/SingleSlotProof.json'
      )
      .toString('ascii')
  );
  const compiledVanillaExecutionStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/ExecutionStrategies/Vanilla.cairo/Vanilla.json'
      )
      .toString('ascii')
  );
  const compiledZodiacRelayerExecutionStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/ExecutionStrategies/ZodiacRelayer.cairo/ZodiacRelayer.json'
      )
      .toString('ascii')
  );
  const compiledStarknetExecutionStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/ExecutionStrategies/Starknet.cairo/Starknet.json'
      )
      .toString('ascii')
  );
  const compiledSpace = json.parse(
    fs
      .readFileSync('./starknet-artifacts/contracts/starknet/Space.cairo/Space.json')
      .toString('ascii')
  );

  const deployTxs = [
    defaultProvider.deployContract({ contract: compiledVanillaAuthenticator }),
    defaultProvider.deployContract({ contract: compiledStarkTxAuthenticator }),
    defaultProvider.deployContract({ contract: compiledVanillaVotingStrategy }),
    defaultProvider.deployContract({ contract: compiledSingleSlotProofVotingStrategy }),
    defaultProvider.deployContract({ contract: compiledVanillaExecutionStrategy }),
    defaultProvider.deployContract({ contract: compiledZodiacRelayerExecutionStrategy }),
    defaultProvider.deployContract({ contract: compiledStarknetExecutionStrategy }),
  ];
  const responses = await Promise.all(deployTxs);
  const vanillaAuthenticatorAddress = responses[0].address!;
  const starkTxAuthenticatorAddress = responses[1].address!;
  const vanillaVotingStrategyAddress = responses[2].address!;
  const singleSlotProofVotingStrategyAddress = responses[3].address!;
  const vanillaExecutionStrategyAddress = responses[4].address!;
  const zodiacRelayerExecutionStrategyAddress = responses[5].address!;
  const starknetExecutionStrategyAddress = responses[6].address!;
  console.log(responses);

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(2000);
  const votingStrategies: bigint[] = [
    BigInt(vanillaVotingStrategyAddress),
    BigInt(singleSlotProofVotingStrategyAddress),
  ];
  const votingStrategyParams: bigint[][] = [
    [],
    [BigInt('0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9'), BigInt(0)],
  ]; // vanilla and Aave token voting
  const votingStrategyParamsFlat: bigint[] = flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [
    BigInt(vanillaAuthenticatorAddress),
    BigInt(starkTxAuthenticatorAddress),
  ];
  const executors: bigint[] = [
    BigInt(vanillaExecutionStrategyAddress),
    BigInt(zodiacRelayerExecutionStrategyAddress),
    BigInt(starknetExecutionStrategyAddress),
  ];
  const quorum: SplitUint256 = SplitUint256.fromUint(BigInt(1)); //  Quorum of one for the vanilla test
  const proposalThreshold: SplitUint256 = SplitUint256.fromUint(BigInt(1)); // Proposal threshold of 1 for the vanilla test
  const controllerAddress = '0x0070d911463b2cb48de8bfec826483631cdc492a6c5798917651297769fc9d68'; // Controller address (orlando's argent x)

  const spaceDeploymentCalldata: bigint[] = [
    votingDelay,
    minVotingDuration,
    maxVotingDuration,
    proposalThreshold.low,
    proposalThreshold.high,
    BigInt(controllerAddress),
    quorum.low,
    quorum.high,
    BigInt(votingStrategyParamsFlat.length),
    ...votingStrategyParamsFlat,
    BigInt(votingStrategies.length),
    ...votingStrategies,
    BigInt(authenticators.length),
    ...authenticators,
    BigInt(executors.length),
    ...executors,
  ];
  const spaceDeploymentCalldataHex = spaceDeploymentCalldata.map((x) => '0x' + x.toString(16));
  const spaceResponse = await defaultProvider.deployContract({
    contract: compiledSpace,
    constructorCalldata: spaceDeploymentCalldataHex,
  });

  const spaceAddress = spaceResponse.address!;

  const deployments = {
    space: {
      name: 'Test space',
      address: spaceAddress,
      controller: controllerAddress,
      minVotingDuration: '0x' + minVotingDuration.toString(16),
      maxVotingDuration: '0x' + maxVotingDuration.toString(16),
      proposalThreshold: proposalThreshold.toHex(),
      quorum: quorum.toHex(),
      authenticators: {
        Vanilla: vanillaAuthenticatorAddress,
        StarkTx: starkTxAuthenticatorAddress,
      },
      votingStrategies: {
        Vanilla: {
          address: vanillaVotingStrategyAddress,
          parameters: [],
        },
        SingleSlotProof: {
          address: singleSlotProofVotingStrategyAddress,
          parameters: ['0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9', '0x0'],
        },
      },
      executionStrategies: {
        Vanilla: vanillaExecutionStrategyAddress,
        zodiacRelayer: zodiacRelayerExecutionStrategyAddress,
        Starknet: starknetExecutionStrategyAddress,
      },
    },
  };

  fs.writeFileSync('./deployments/goerli2.json', JSON.stringify(deployments));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
