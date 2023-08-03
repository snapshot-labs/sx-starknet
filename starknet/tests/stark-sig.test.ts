import fs from 'fs';
import dotenv from 'dotenv';
import { Provider, Account, CallData, Calldata, typedData, json } from 'starknet';
import {
  proposeTypes,
  voteTypes,
  updateProposalTypes,
  Propose,
  Vote,
  UpdateProposal,
  StarknetSigProposeCalldata,
  StarknetSigVoteCalldata,
  StarknetSigUpdateProposalCalldata,
} from './types';

dotenv.config();

describe('Starknet Signature Authenticator', () => {
  const provider = new Provider({ sequencer: { baseUrl: 'http://127.0.0.1:5050' } });
  // devnet predeployed account
  const privateKey0 = '0xe3e70682c2094cac629f6fbed82c07cd';
  const address0 = '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a';
  const publickey0 = '0x7e52885445756b313ea16849145363ccb73fb4ab0440dbac333cf9d13de82b9';
  const account0 = new Account(provider, address0, privateKey0);

  let starkSigAuthAddress: string;
  let domain: any;

  beforeAll(async () => {
    const compiledContractSierra = json.parse(
      fs.readFileSync('starknet/target/dev/sx_StarkSigAuthenticator.sierra.json').toString('ascii'),
    );
    const compiledContractCasm = json.parse(
      fs.readFileSync('starknet/target/dev/sx_StarkSigAuthenticator.casm.json').toString('ascii'),
    );

    const contractConstructor: Calldata = CallData.compile({
      name: 'sx-sn',
      version: '0.1.0',
    });

    const deployResponse = await account0.declareAndDeploy({
      contract: compiledContractSierra,
      casm: compiledContractCasm,
      constructorCalldata: contractConstructor,
    });
    starkSigAuthAddress = deployResponse.deploy.contract_address;
    domain = {
      name: 'sx-sn',
      version: '0.1.0',
      chainId: '0x534e5f474f45524c49', // devnet id
      verifyingContract: starkSigAuthAddress,
    };
  }, 100000);
  test('can authenticate a proposal, a vote, and a proposal update', async () => {
    // PROPOSE
    const proposeMsg: Propose = {
      space: '0x0000000000000000000000000000000000007777',
      author: '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a',
      executionStrategy: {
        address: '0x0000000000000000000000000000000000001234',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      userProposalValidationParams: ['0x1', '0x2', '0x3', '0x4'],
      salt: '0x0',
    };

    const proposeData: typedData.TypedData = {
      types: proposeTypes,
      primaryType: 'Propose',
      domain: domain,
      message: proposeMsg as any,
    };

    const proposeSig = (await account0.signMessage(proposeData)) as any;

    const proposeCalldata: StarknetSigProposeCalldata = {
      r: proposeSig.r,
      s: proposeSig.s,
      ...proposeMsg,
      public_key: publickey0,
    };

    await account0.execute({
      contractAddress: starkSigAuthAddress,
      entrypoint: 'authenticate_propose',
      calldata: CallData.compile(proposeCalldata as any),
    });

    // VOTE

    const voteMsg: Vote = {
      space: '0x0000000000000000000000000000000000007777',
      voter: '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a',
      proposalId: { low: '0x1', high: '0x0' },
      choice: '0x1',
      userVotingStrategies: [
        { index: '0x1', params: ['0x1', '0x2', '0x3', '0x4'] },
        { index: '0x2', params: [] },
      ],
    };

    const voteData: typedData.TypedData = {
      types: voteTypes,
      primaryType: 'Vote',
      domain: domain,
      message: voteMsg as any,
    };

    const voteSig = (await account0.signMessage(voteData)) as any;

    const voteCalldata: StarknetSigVoteCalldata = {
      r: voteSig.r,
      s: voteSig.s,
      ...voteMsg,
      public_key: publickey0,
    };

    await account0.execute({
      contractAddress: starkSigAuthAddress,
      entrypoint: 'authenticate_vote',
      calldata: CallData.compile(voteCalldata as any),
    });

    // UPDATE PROPOSAL

    const updateProposalMsg: UpdateProposal = {
      space: '0x0000000000000000000000000000000000007777',
      author: '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a',
      proposalId: { low: '0x1', high: '0x0' },
      executionStrategy: {
        address: '0x0000000000000000000000000000000000001234',
        params: ['0x5', '0x6', '0x7', '0x8'],
      },
      salt: '0x0',
    };
    const updateProposalData: typedData.TypedData = {
      types: updateProposalTypes,
      primaryType: 'UpdateProposal',
      domain: domain,
      message: updateProposalMsg as any,
    };

    const updateProposalSig = (await account0.signMessage(updateProposalData)) as any;

    const updateProposalCalldata: StarknetSigUpdateProposalCalldata = {
      r: updateProposalSig.r,
      s: updateProposalSig.s,
      ...updateProposalMsg,
      public_key: publickey0,
    };

    await account0.execute({
      contractAddress: starkSigAuthAddress,
      entrypoint: 'authenticate_update_proposal',
      calldata: CallData.compile(updateProposalCalldata as any),
    });
  }, 100000);
});
