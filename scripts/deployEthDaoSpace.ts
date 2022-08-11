import fs from 'fs';
import { defaultProvider, Account, ec, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {
  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );

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
      .readFileSync('./starknet-artifacts/contracts/starknet/SpaceAccount.cairo/SpaceAccount.json')
      .toString('ascii')
  );
  const spaceClassHash = '0x75fe4cc03bb9bf2252455199b5ee6757800ea02719b3f1b7d968a46b3ddaa78';
  const fossilFactRegistryAddress =
    '0x363108ac1521a47b4f7d82f8ba868199bc1535216bbedfc1b071ae93cc406fd';
  const fossilL1HeadersStoreAddress =
    '0x6ca3d25e901ce1fff2a7dd4079a24ff63ca6bbf8ba956efc71c1467975ab78f';

  const deployTxs = [
    defaultProvider.deployContract({ contract: compiledVanillaAuthenticator }),
    defaultProvider.deployContract({ contract: compiledEthSigAuthenticator }),
    defaultProvider.deployContract({ contract: compiledVanillaVotingStrategy }),
    defaultProvider.deployContract({
      contract: compiledSingleSlotProofVotingStrategy,
      constructorCalldata: [fossilFactRegistryAddress, fossilL1HeadersStoreAddress],
    }),
    defaultProvider.deployContract({ contract: compiledVanillaExecutionStrategy }),
    defaultProvider.deployContract({
      contract: compiledSpaceFactory,
      constructorCalldata: [spaceClassHash],
    }),
  ];
  const responses = await Promise.all(deployTxs);
  const vanillaAuthenticatorAddress = responses[0].address!;
  const ethSigAuthenticatorAddress = responses[1].address!;
  const vanillaVotingStrategyAddress = responses[2].address!;
  const singleSlotProofVotingStrategyAddress = responses[3].address!;
  const vanillaExecutionStrategyAddress = responses[4].address!;
  const spaceFactoryAddress = responses[5].address!;

  const votingDelay = 0;
  const minVotingDuration = 0;
  const maxVotingDuration = 200000;
  const votingStrategies = [vanillaVotingStrategyAddress, singleSlotProofVotingStrategyAddress];
  // First voting strategy is vanilla which has zero paramaters.
  // Second voting strategy is single slot proof which has two parameters, the contract address and the slot index.
  const votingStrategyParams = [[], ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3']];
  const votingStrategyParamsFlat = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators = [ethSigAuthenticatorAddress, vanillaAuthenticatorAddress];
  const executors = [vanillaExecutionStrategyAddress];
  const quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const proposalThreshold = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const controllerAddress = '0x0764c647e4c5f6e81c5baa1769b4554e44851a7b6319791fc6db9e25a32148bb'; // Controller address is orlando's argent x)

  // Deploy space contract through space factory.
  const { transaction_hash: txHash } = await starkAccount.execute(
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
        votingStrategyParamsFlat.length,
        ...votingStrategyParamsFlat,
        votingStrategies.length,
        ...votingStrategies,
        authenticators.length,
        ...authenticators,
        executors.length,
        ...executors,
      ],
    },
    undefined,
    { maxFee: '857400005301800' }
  );
  console.log('waiting for space to be deployed, transaction hash: ', txHash);
  await defaultProvider.waitForTransaction(txHash);

  // Extracting space address from the event emitted by the space factory.
  const receipt = (await defaultProvider.getTransactionReceipt(txHash)) as any;
  const spaceAddress = receipt.events[1].data[1];

  // Storing deployment config.
  const deployments = {
    spaceFactory: {
      address: spaceFactoryAddress,
      spaceClassHash: spaceClassHash,
    },
    space: {
      name: 'Ethereum DAO test space',
      address: spaceAddress,
      controller: controllerAddress,
      minVotingDuration: minVotingDuration,
      maxVotingDuration: maxVotingDuration,
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
  fs.writeFileSync('./deployments/goerli1.json', JSON.stringify(deployments));
  console.log('---- DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
