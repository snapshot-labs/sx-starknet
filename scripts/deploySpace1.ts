import fs from 'fs';
import { defaultProvider, Account, ec, json } from 'starknet';
import { utils } from '@snapshot-labs/sx';

async function main() {
  const starkAccount = new Account(
    defaultProvider,
    process.env.ARGENT_X_ADDRESS!,
    ec.getKeyPair(process.env.ARGENT_X_PK!)
  );
  const spaceClassHash = '0x75fe4cc03bb9bf2252455199b5ee6757800ea02719b3f1b7d968a46b3ddaa78';
  const spaceFactoryAddress = '0x3e5165026e6586cd2d5cdf1fdced8af866f900e430bf1dc7b839c84604c506e';
  const votingDelay = 0;
  const minVotingDuration = 0;
  const maxVotingDuration = 200000;
  const votingStrategies = ['0x4bbd8081b1e9ef84ee2a767ef2cdcdea0dd8298b8e2858afa06bed1898533e6'];
  // First voting strategy is vanilla which has zero paramaters.
  // Second voting strategy is single slot proof which has two parameters, the contract address and the slot index.
  const votingStrategyParams: string[][] = [['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3']];
  const votingStrategyParamsFlat = utils.encoding.flatten2DArray(votingStrategyParams);
  const authenticators = ['0x594a81b66c3aa2c64577916f727e1307b60c9d6afa80b6f5ca3e3049c40f643'];
  const executors = ['0x7402b474327a0d7a2d5c3e01489386113d9654eaff8591344577458074bb1b7'];
  const quorum = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const proposalThreshold = utils.splitUint256.SplitUint256.fromUint(BigInt(1));
  const controllerAddress = '0x0764c647e4c5f6e81c5baa1769b4554e44851a7b6319791fc6db9e25a32148bb'; // Controller address is orlando's argent x)

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
  //   const deployments = {
  //     spaceFactory: {
  //       address: spaceFactoryAddress,
  //       spaceClassHash: spaceClassHash,
  //     },
  //     space: {
  //       name: 'Ethereum DAO test space',
  //       address: spaceAddress,
  //       controller: controllerAddress,
  //       minVotingDuration: minVotingDuration,
  //       maxVotingDuration: maxVotingDuration,
  //       proposalThreshold: proposalThreshold.toHex(),
  //       quorum: quorum.toHex(),
  //       authenticators: {
  //         EthSig: ethSigAuthenticatorAddress,
  //         Vanilla: vanillaAuthenticatorAddress,
  //       },
  //       votingStrategies: {
  //         SingleSlotProof: {
  //           address: singleSlotProofVotingStrategyAddress,
  //           parameters: ['0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', '0x3'],
  //         },
  //         Vanilla: {
  //           address: vanillaVotingStrategyAddress,
  //           parameters: [],
  //         },
  //       },
  //       executionStrategies: {
  //         Vanilla: vanillaExecutionStrategyAddress,
  //       },
  //     },
  //   };
  //   fs.writeFileSync('./deployments/goerli1.json', JSON.stringify(deployments));
  console.log('---- DEPLOYMENT COMPLETE ----');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
