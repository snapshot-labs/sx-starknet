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
  console.log('vanillaAuthenticatorAddress', vanillaAuthenticatorAddress);
  console.log('ethSigAuthenticatorAddress', ethSigAuthenticatorAddress);
  console.log('vanillaVotingStrategyAddress', vanillaVotingStrategyAddress);
  console.log('singleSlotProofVotingStrategyAddress', singleSlotProofVotingStrategyAddress);
  console.log('vanillaExecutionStrategyAddress', vanillaExecutionStrategyAddress);
  console.log('spaceFactoryAddress', spaceFactoryAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
