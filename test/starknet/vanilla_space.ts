import { stark } from 'starknet';
import { SplitUint256, FOR } from './shared/types';
import { flatten2DArray, getProposeCalldata } from './shared/helpers';
import { strToShortStringArr } from '@snapshot-labs/sx';
import { expect } from 'chai';
import {
  vanillaSetup,
  VITALIK_ADDRESS,
  VITALIK_STRING_ADDRESS,
  EXECUTE_METHOD,
  PROPOSAL_METHOD,
  VOTE_METHOD,
  MIN_VOTING_DURATION,
  MAX_VOTING_DURATION,
} from './shared/setup';
import { StarknetContract } from 'hardhat/types';

const { getSelectorFromName } = stark;

describe('Space testing', () => {
  let space: StarknetContract;
  let spaceAddress: bigint;
  let vanillaAuthenticator: StarknetContract;
  let vanillaVotingStrategy: StarknetContract;
  let zodiacRelayer: StarknetContract;
  let zodiacRelayerAddress: bigint;
  let executionHash: string; 
  let metadataUri: bigint[]; 
  let proposerAddress: string; 
  let proposalId: bigint; 
  let usedVotingStrategies: bigint[];
  let votingParamsAll: bigint[][]; 
  let l1ZodiacModule: bigint; 
  let executionParams: bigint[]; 
  let ethBlockNumber: bigint; 
  let proposeCalldata: bigint[];
  
  before(async function () {
    this.timeout(800000);

    ({ space, vanillaAuthenticator, vanillaVotingStrategy, zodiacRelayer } = await vanillaSetup());

    executionHash = '0x912ea662aac9d054ef5173da69723b88a5582cae2349f891998b6040cf9c2653'; // Random 32 byte hash
    metadataUri = strToShortStringArr('Hello and welcome to Snapshot X. This is the future of governance.');
    proposerAddress = '0xd8da6bf26964af9d7eed9e03e53415d37aa96045';
    proposalId = BigInt(1);
    ethBlockNumber = BigInt(1337);
    spaceAddress = BigInt(space.address);
    zodiacRelayerAddress = BigInt(zodiacRelayer.address);
    usedVotingStrategies = [BigInt(vanillaVotingStrategy.address)];
    votingParamsAll = [[]];
    l1ZodiacModule = BigInt('0x1234');
    executionParams = [BigInt(l1ZodiacModule)]
    proposeCalldata = getProposeCalldata(
      proposerAddress, 
      executionHash, 
      metadataUri, 
      ethBlockNumber, 
      zodiacRelayerAddress, 
      usedVotingStrategies, 
      votingParamsAll, 
      executionParams
    );
  });

  it('Should create a proposal and cast a vote', async () => {
    // -- Creates the proposal --
    {
      console.log('Creating proposal...');
      await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
        target: spaceAddress,
        function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
        calldata: proposeCalldata
      });

      console.log('Getting proposal info...');
      const { proposal_info } = await space.call('get_proposal_info', {
        proposal_id: proposalId,
      });

      // We can't directly compare the `info` object because we don't know for sure the value of `start_block` (and hence `end_block`),
      // so we compare it element by element.
      const _executionHash = SplitUint256.fromObj(proposal_info.proposal.execution_hash).toHex();
      expect(_executionHash).to.deep.equal(executionHash);

      const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
      expect(_for).to.deep.equal(BigInt(0));
      const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
      expect(against).to.deep.equal(BigInt(0));
      const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
      expect(abstain).to.deep.equal(BigInt(0));
    }

    // // -- Casts a vote FOR --
    // {
    //   console.log('Casting a vote FOR...');
    //   const voter_address = proposerAddress.value;
    //   const votingParamsAll: bigint[][] = [[]];
    //   // Cairo cannot handle 2D arrays in calldata so we must flatten the data then reconstruct the individual arrays inside the contract
    //   const votingParamsAllFlat = flatten2DArray(votingParamsAll);
    //   const used_voting_strategies = [BigInt(vanillaVotingStrategy.address)];
    //   await vanillaAuthenticator.invoke(EXECUTE_METHOD, {
    //     target: spaceAddress,
    //     function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
    //     calldata: [
    //       voter_address,
    //       proposalId,
    //       FOR,
    //       BigInt(used_voting_strategies.length),
    //       ...used_voting_strategies,
    //       BigInt(votingParamsAllFlat.length),
    //       ...votingParamsAllFlat,
    //     ],
    //   });

    //   console.log('Getting proposal info...');
    //   const { proposal_info } = await space.call('get_proposal_info', {
    //     proposal_id: proposalId,
    //   });

    //   const _for = SplitUint256.fromObj(proposal_info.power_for).toUint();
    //   expect(_for).to.deep.equal(BigInt(1));
    //   const against = SplitUint256.fromObj(proposal_info.power_against).toUint();
    //   expect(against).to.deep.equal(BigInt(0));
    //   const abstain = SplitUint256.fromObj(proposal_info.power_abstain).toUint();
    //   expect(abstain).to.deep.equal(BigInt(0));
    // }
  }).timeout(6000000);
});
