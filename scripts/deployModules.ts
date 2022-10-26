import fs from 'fs';
import { Provider, defaultProvider, Account, ec, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {
  const provider = process.env.STARKNET_PROVIDER_BASE_URL === undefined ?
  defaultProvider :
    new Provider({
      sequencer: {
        baseUrl: process.env.STARKNET_PROVIDER_BASE_URL!,
        feederGatewayUrl: 'feeder_gateway',
        gatewayUrl: 'gateway',
      }, 
  });

  const starkAccount = new Account(
    provider,
    process.env.ACCOUNT_ADDRESS!,
    ec.getKeyPair(process.env.ACCOUNT_PRIVATE_KEY!)
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
  const compiledEthBalanceOfVotingStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/VotingStrategies/EthBalanceOf.cairo/EthBalanceOf.json'
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
  const spaceClassHash = "0x591469387a06fb88dd66559f4bc91e4c0c1e61e65c259b14a4d43f274fdabd9";

  const l1MessagesSenderAddress = '0x738bfb83246156b759165d244077865B994F9d33';
  const fossilFactRegistryAddress =
    '0x363108ac1521a47b4f7d82f8ba868199bc1535216bbedfc1b071ae93cc406fd';
  const fossilL1HeadersStoreAddress =
    '0x6ca3d25e901ce1fff2a7dd4079a24ff63ca6bbf8ba956efc71c1467975ab78f';

  const deployTxs = [
    provider.deployContract({ contract: compiledVanillaAuthenticator }),
    provider.deployContract({ contract: compiledEthSigAuthenticator }),
    provider.deployContract({ contract: compiledVanillaVotingStrategy }),
    provider.deployContract({ contract: compiledVanillaVotingStrategy }),
    provider.deployContract({ contract: compiledVanillaExecutionStrategy }),
    provider.deployContract({ contract: compiledZodiacExecutionStrategy }),
    provider.deployContract({
      contract: compiledSpaceFactory,
      constructorCalldata: [spaceClassHash],
    }),
  ];
  const responses = await Promise.all(deployTxs);
  console.log(responses);
  const vanillaAuthenticatorAddress = responses[0].contract_address!;
  const ethSigAuthenticatorAddress = responses[1].contract_address!;
  const vanillaVotingStrategyAddress = responses[2].contract_address!;
  const ethBalanceOfVotingStrategyAddress = responses[3].contract_address!;
  const vanillaExecutionStrategyAddress = responses[4].contract_address!;
  const zodiacExecutionStrategyAddress = responses[5].contract_address!;
  const spaceFactoryAddress = responses[6].contract_address!;

  // Storing deployment config.
  const modules = {
    authenticators: {
      vanilla: vanillaAuthenticatorAddress,
      ethSig: ethSigAuthenticatorAddress,
    },
    votingStrategies: {
      vanilla: vanillaVotingStrategyAddress,
      ethBalanceOf: {
        address: ethBalanceOfVotingStrategyAddress,
        l1MessagesSender: l1MessagesSenderAddress,
        fossilFactRegistry: fossilFactRegistryAddress,
        fossilL1HeadersStore: fossilL1HeadersStoreAddress,
      },
    },
    executionStrategies: {
      vanilla: vanillaExecutionStrategyAddress,
      zodiac: zodiacExecutionStrategyAddress,
    },
    spaceFactory: {
      address: spaceFactoryAddress,
      spaceClassHash: spaceClassHash,
    },
  };

  fs.writeFileSync('./deployments/modules2.json', JSON.stringify(modules));
  console.log('---- MODULE DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
