import fs from 'fs';
import { defaultProvider, Account, ec, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {
  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );

  const vanillaAuthenticatorAddress =
    '0x17dcb5cfee6763f4aebfc99e94bcd607756703a7f8bc633c66dcb7c82577a18';
  const ethSigAuthenticatorAddress =
    '0x4e1e37fafcea50aafdbe5658cebc5712fc043b07dfcac5983f818db20508979';
  const vanillaVotingStrategyAddress =
    '0x76494a9bf97703bfee2c44685e10b8242dc03c40f0a2b129db47baf38f5cdfb';
  const ethBalanceOfVotingStrategyAddress =
    '0x23787b1c10adc91ecf15c772ab2f3a489fb461b9dc82226270e51a0b8fe5a0e';
  const vanillaExecutionStrategyAddress =
    '0x2fa09cdb0f8bf7a0c08ed48bb9b4a9c06eab026a24c22c2842552dfc9a40b80';
  const zodiacExecutionStrategyAddress =
    '0x7a0c890e6dc4dc445fb42c70579813ea33e7d3c37c2cfdbcb47cc059503747d';

  const spaceFactoryAddress = '0x2e364670ba4f805d667dc4d220c0f8385b1678bd1ca329ca0f969b3c92b62e0';

  const spaceClassHash = '0xf6a58610d0ce607f69fcc3df1559baacd0b1f06c452dc57a53320168d97bf8';
  const votingDelay = 0;
  const minVotingDuration = 0;
  const maxVotingDuration = 200000;
  const votingStrategies = [vanillaVotingStrategyAddress, ethBalanceOfVotingStrategyAddress];
  // First voting strategy is vanilla which has zero paramaters.
  // Second voting strategy is eth balance of which has two parameters, the contract address and the slot index.
  const votingStrategyParams: string[][] = [
    [],
    ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3'],
  ];
  const votingStrategyParamsFlat = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators = [vanillaAuthenticatorAddress, ethSigAuthenticatorAddress];
  const executors = [vanillaExecutionStrategyAddress, zodiacExecutionStrategyAddress];
  const quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const proposalThreshold = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const controllerAddress = '0x0764c647e4c5f6e81c5baa1769b4554e44851a7b6319791fc6db9e25a32148bb'; // Controller address is orlando's argent x

  // Deploy space contract through space factory.
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
    ],
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
      name: 'DAO test space',
      address: spaceAddress,
      controller: controllerAddress,
      minVotingDuration: minVotingDuration,
      maxVotingDuration: maxVotingDuration,
      proposalThreshold: proposalThreshold.toHex(),
      quorum: quorum.toHex(),
      authenticators: {
        ethSig: ethSigAuthenticatorAddress,
        vanilla: vanillaAuthenticatorAddress,
      },
      votingStrategies: {
        vanilla: {
          index: 0,
          address: vanillaVotingStrategyAddress,
          parameters: [],
        },
        ethBalanceOf: {
          index: 1,
          address: ethBalanceOfVotingStrategyAddress,
          parameters: ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3'],
        },
      },
      executionStrategies: {
        vanilla: vanillaExecutionStrategyAddress,
        zodiac: zodiacExecutionStrategyAddress,
      },
    },
  };
  fs.writeFileSync('./deployments/goerli2.json', JSON.stringify(deployments));
  console.log('---- DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
