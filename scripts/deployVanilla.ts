import fs from 'fs';
import {
  Contract,
  Account,
  defaultProvider,
  ec,
  encode,
  hash,
  json,
  number,
  stark, 
  RawCalldata
} from 'starknet';
import { toBN } from 'starknet/dist/utils/number';
import BN, { isBN } from 'bn.js';
import { BigNumberish } from 'ethers';
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
  const compiledVanillaVotingStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/Authenticators/Vanilla.cairo/Vanilla.json'
      )
      .toString('ascii')
  );
  const compiledVanillaExecutionStrategy = json.parse(
    fs
      .readFileSync(
        './starknet-artifacts/contracts/starknet/Authenticators/Vanilla.cairo/Vanilla.json'
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
    defaultProvider.deployContract({ contract: compiledVanillaVotingStrategy }),
    defaultProvider.deployContract({ contract: compiledVanillaExecutionStrategy }),
  ];
  const responses = await Promise.all(deployTxs);
  const vanillaAuthenticatorAddress = responses[0].address!;
  const vanillaVotingStrategyAddress = responses[1].address!;
  const vanillaExecutionStrategyAddress = responses[2].address!;

  console.log(responses);

  const votingDelay = 0;
  const minVotingDuration = 0;
  const maxVotingDuration = 2000;

  const votingStrategies: BigNumberish[] = [vanillaVotingStrategyAddress];

  const votingStrategyParams: bigint[][] = [[]]; // No params for the vanilla voting strategy
  const votingStrategyParamsFlat: BigNumberish[] = flatten2DArray(votingStrategyParams).map((x) => '0x'+x.toString(16));

  const authenticators: BigNumberish[] = [vanillaAuthenticatorAddress];
  const executors: BigNumberish[] = [vanillaExecutionStrategyAddress];

  const quorum = 1; //  Quorum of one 
  const proposalThreshold = 1; // Proposal threshold of 1 for the vanilla test

  const controller = 100;


  const spaceDeploymentCalldata = [
    ...votingStrategyParamsFlat, 
    ...votingStrategies, 
    ...authenticators, 
    ...executors
    ];

  //   votingDelay, 
  //   minVotingDuration, 
  //   maxVotingDuration, 
  //   proposalThreshold,
  //   0

  // ];
    // controller,
    // quorum,
    // 0,
    // ...votingStrategyParamsFlat, 
    // ...votingStrategies, 
    // ...authenticators, 
    // ...executors
    // ];

    console.log(spaceDeploymentCalldata);

    // Just get the big int array then convert entire thing to bignumberish array

  const spaceResponse = await defaultProvider.deployContract({contract: compiledSpace, constructorCalldata: spaceDeploymentCalldata});
  console.log(spaceResponse)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
