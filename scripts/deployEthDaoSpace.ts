import fs from 'fs';
import { defaultProvider, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {
  const compiledVanillaAuthenticator = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/Authenticators/Vanilla.cairo/Vanilla.json'
      )
      .toString('ascii')
  );
  const compiledEthSigAuthenticator = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/Authenticators/EthSig.cairo/EthSig.json'
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
  const compiledSpaceFactory = json.parse(
    fs
      .readFileSync('./starknet-artifacts/contracts/starknet/SpaceFactory.cairo/SpaceFactory.json')
      .toString('ascii')
  );
  const compiledSpace = json.parse(
    fs
      .readFileSync('./starknet-artifacts/contracts/starknet/Space.cairo/Space.json')
      .toString('ascii')
  );

  const deployTxs = [
    defaultProvider.deployContract({ contract: compiledVanillaAuthenticator }),
    defaultProvider.deployContract({ contract: compiledEthSigAuthenticator }),
    defaultProvider.deployContract({ contract: compiledVanillaVotingStrategy }),
    defaultProvider.deployContract({ contract: compiledSingleSlotProofVotingStrategy }),
    defaultProvider.deployContract({ contract: compiledVanillaExecutionStrategy }),
  ];
  const responses = await Promise.all(deployTxs);
  const vanillaAuthenticatorAddress = responses[0].address!;
  const ethSigAuthenticatorAddress = responses[1].address!;
  const vanillaVotingStrategyAddress = responses[2].address!;
  const singleSlotProofVotingStrategyAddress = responses[3].address!;
  const vanillaExecutionStrategyAddress = responses[4].address!;

  console.log(responses);

  const votingDelay = BigInt(0);
  const minVotingDuration = BigInt(0);
  const maxVotingDuration = BigInt(200000);
  const votingStrategies: bigint[] = [
    BigInt(vanillaVotingStrategyAddress),
    BigInt(singleSlotProofVotingStrategyAddress),
  ];
  const votingStrategyParams: bigint[][] = [
    [],
    [BigInt('0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6'), BigInt(3)],
  ]; // WETH erc20 balance voting
  const votingStrategyParamsFlat: bigint[] = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators: bigint[] = [
    BigInt(ethSigAuthenticatorAddress),
    BigInt(vanillaAuthenticatorAddress),
  ];
  const executors: bigint[] = [BigInt(vanillaExecutionStrategyAddress)];
  const quorum: utils.splitUint256.SplitUint256 = utils.splitUint256.SplitUint256.fromUint(
    BigInt(1)
  ); //  Quorum of one for the vanilla test
  const proposalThreshold: utils.splitUint256.SplitUint256 =
    utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const controllerAddress = '0x0764c647e4c5f6e81c5baa1769b4554e44851a7b6319791fc6db9e25a32148bb'; // Controller address (orlando's argent x)

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
      name: 'Ethereum DAO test space',
      address: spaceAddress,
      controller: controllerAddress,
      minVotingDuration: '0x' + minVotingDuration.toString(16),
      maxVotingDuration: '0x' + maxVotingDuration.toString(16),
      proposalThreshold: proposalThreshold.toHex(),
      quorum: quorum.toHex(),
      authenticators: {
        EthSig: ethSigAuthenticatorAddress,
        Vanilla: vanillaAuthenticatorAddress,
      },
      votingStrategies: {
        SingleSlotProof: {
          address: singleSlotProofVotingStrategyAddress,
          parameters: ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3'],
        },
        Vanilla: {
          address: vanillaVotingStrategyAddress,
          parameters: [],
        },
      },
      executionStrategies: {
        Vanilla: vanillaExecutionStrategyAddress,
      },
    },
  };

  fs.writeFileSync('./deployments/goerli3.json', JSON.stringify(deployments));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
