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
  // const compiledEthBalanceOfVotingStrategy = json.parse(
  //   fs
  //     .readFileSync(
  //       './starknet-artifacts/contracts/starknet/VotingStrategies/EthBalanceOf.cairo/EthBalanceOf.json'
  //     )
  //     .toString('ascii')
  // );
  const compiledVanillaExecutionStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/ExecutionStrategies/Vanilla.cairo/Vanilla.json'
      )
      .toString('ascii')
  );
  const compiledZodiacExecutionStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/ExecutionStrategies/EthRelayer.cairo/EthRelayer.json'
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

  // Obtained via declaring the space account contract:
  // starknet declare --contract ./starknet-artifacts/contracts/starknet/SpaceAccount.cairo/SpaceAccount.json

  

  const out = await starkAccount.declare({contract: compiledSpace, });
  console.log(out);

  // const spaceClassHash = '0x11d33854aa6fd7fee2082075bae9a16ad121f85cbd0a9f357474d7f4ba17cb7';
  // const l1MessagesSenderAddress = '0x738bfb83246156b759165d244077865B994F9d33';
  // const fossilFactRegistryAddress =
  //   '0x363108ac1521a47b4f7d82f8ba868199bc1535216bbedfc1b071ae93cc406fd';
  // const fossilL1HeadersStoreAddress =
  //   '0x6ca3d25e901ce1fff2a7dd4079a24ff63ca6bbf8ba956efc71c1467975ab78f';

  // const deployTxs = [
  //   defaultProvider.deployContract({ contract: compiledVanillaAuthenticator }),
  //   defaultProvider.deployContract({ contract: compiledEthSigAuthenticator }),
  //   defaultProvider.deployContract({ contract: compiledVanillaVotingStrategy }),
  //   defaultProvider.deployContract({ contract: compiledVanillaVotingStrategy }),
  //   defaultProvider.deployContract({ contract: compiledVanillaExecutionStrategy }),
  //   defaultProvider.deployContract({ contract: compiledZodiacExecutionStrategy }),
  //   defaultProvider.deployContract({
  //     contract: compiledSpaceFactory,
  //     constructorCalldata: [spaceClassHash],
  //   }),
  // ];
  // const responses = await Promise.all(deployTxs);
  // const vanillaAuthenticatorAddress = responses[0].contract_address!;
  // const ethSigAuthenticatorAddress = responses[1].contract_address!;
  // const vanillaVotingStrategyAddress = responses[2].contract_address!;
  // const ethBalanceOfVotingStrategyAddress = responses[3].contract_address!;
  // const vanillaExecutionStrategyAddress = responses[4].contract_address!;
  // const zodiacExecutionStrategyAddress = responses[5].contract_address!;
  // const spaceFactoryAddress = responses[6].contract_address!;

  // // Storing deployment config.
  // const modules = {
  //   authenticators: {
  //     vanilla: vanillaAuthenticatorAddress,
  //     ethSig: ethSigAuthenticatorAddress,
  //   },
  //   votingStrategies: {
  //     vanilla: vanillaVotingStrategyAddress,
  //     ethBalanceOf: {
  //       address: ethBalanceOfVotingStrategyAddress,
  //       l1MessagesSender: l1MessagesSenderAddress,
  //       fossilFactRegistry: fossilFactRegistryAddress,
  //       fossilL1HeadersStore: fossilL1HeadersStoreAddress,
  //     },
  //   },
  //   executionStrategies: {
  //     vanilla: vanillaExecutionStrategyAddress,
  //     zodiac: zodiacExecutionStrategyAddress,
  //   },
  //   spaceFactory: {
  //     address: spaceFactoryAddress,
  //     spaceClassHash: spaceClassHash,
  //   },
  // };

  // fs.writeFileSync('./deployments/modules.json', JSON.stringify(modules));
  // console.log('---- MODULE DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
