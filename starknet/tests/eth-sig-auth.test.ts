import fs from 'fs';
import { ethers } from "ethers";
import { Provider, Account, Contract, CallData, cairo, shortString, json, Calldata } from 'starknet';
import { Propose, proposeTypes, EthereumSigProposeCalldata, voteTypes, Vote, updateProposalTypes, UpdateProposal} from "./types";

const pk = process.env.PRIVATE_KEY || '';

describe('Starknet Signature Authenticator', () => {
  const signer = new ethers.Wallet(pk);
  const provider = new Provider({ sequencer: { baseUrl: 'http://127.0.0.1:5050' } });
  // devnet predeployed account
  const privateKey0 = '0xe3e70682c2094cac629f6fbed82c07cd';
  const address0 = '0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a';
  const account0 = new Account(provider, address0, privateKey0);

  let ethSigAuthAddress: string;
  let ethSigAuth: Contract;
  let domain: any;

  beforeAll(async () => {
    // Deploy Ethereum Signature Authenticator
    const ethSigAuthSierra = json.parse(fs.readFileSync( "starknet/target/dev/sx_EthSigAuthenticator.sierra.json").toString( "ascii"));
    const ethSigAuthCasm = json.parse(fs.readFileSync( "starknet/target/dev/sx_EthSigAuthenticator.casm.json").toString( "ascii"));

    const deployResponse = await account0.declareAndDeploy({ contract: ethSigAuthSierra, casm: ethSigAuthCasm, constructorCalldata: CallData.compile({})});

    ethSigAuthAddress = deployResponse.deploy.contract_address;

    const {abi: ethSigAuthAbi} = await provider.getClassAt(ethSigAuthAddress);
    ethSigAuth = new Contract(ethSigAuthAbi, ethSigAuthAddress, provider);
 
    domain = {
      chainId: '0x534e5f474f45524c49', // devnet id
    };
  }, 100000);
  test('can authenticate a proposal, a vote, and a proposal update', async () => {
    // PROPOSE

    const proposeMsg: Propose = {
        authenticator: ethSigAuthAddress,        
        space: "0x0000000000000000000000000000000000001234",
        author: signer.address,
        executionStrategy: {
            address: "0x0000000000000000000000000000000000005678",
            params: ["0x0"]
        },
        userProposalValidationParams: ["0xffffffffffffffffffffffffffffffffffffffffff", "0x1234", "0x5678", "0x9abc"],
        salt: "0x7"
    }

    let sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    let splitSig = getRSVFromSig(sig);

    const proposeCalldata = {
        r: cairo.uint256(splitSig.r),
        s: cairo.uint256(splitSig.s),
        v: splitSig.v,
        space: proposeMsg.space,
        author: proposeMsg.author,
        executionStrategy: proposeMsg.executionStrategy,
        userProposalValidationParams: proposeMsg.userProposalValidationParams,
        salt: cairo.uint256(proposeMsg.salt)
    }

    let result = await account0.execute({
        contractAddress: ethSigAuthAddress,
        entrypoint: "authenticate_propose",
        calldata: CallData.compile(proposeCalldata as any),
    });

    console.log(result);

    // VOTE 

    const voteMsg: Vote = {
        authenticator: ethSigAuthAddress,
        space: "0x0000000000000000000000000000000000001234",
        voter: signer.address,
        proposalId: "0x1",
        choice: "0x1",
        userVotingStrategies: [{ index: '0x0', params: ['0x1', '0x2', '0x3', '0x4'] }]
    }

    sig = await signer.signTypedData(domain, voteTypes, voteMsg);
    splitSig = getRSVFromSig(sig);

    const voteCalldata = {
        r: cairo.uint256(splitSig.r),
        s: cairo.uint256(splitSig.s),
        v: splitSig.v,
        space: voteMsg.space,
        voter: voteMsg.voter,
        proposalId: cairo.uint256(voteMsg.proposalId),
        choice: voteMsg.choice,
        userVotingStrategies: voteMsg.userVotingStrategies
    }

    result = await account0.execute({
        contractAddress: ethSigAuthAddress,
        entrypoint: "authenticate_vote",
        calldata: CallData.compile(voteCalldata as any),
    });

    console.log(result);

    const updateProposalMsg: UpdateProposal = {
        authenticator: ethSigAuthAddress,
        space: "0x0000000000000000000000000000000000001234",
        author: signer.address,
        proposalId: "0x1",
        executionStrategy: {
            address: "0x0000000000000000000000000000000000005678",
            params: ["0x0"]
        },
        salt: "0x7"
    }

    sig = await signer.signTypedData(domain, updateProposalTypes, updateProposalMsg);
    splitSig = getRSVFromSig(sig);

    const updateProposalCalldata = {
        r: cairo.uint256(splitSig.r),
        s: cairo.uint256(splitSig.s),
        v: splitSig.v,
        space: updateProposalMsg.space,
        author: updateProposalMsg.author,
        proposalId: cairo.uint256(updateProposalMsg.proposalId),
        executionStrategy: updateProposalMsg.executionStrategy,
        salt: cairo.uint256(updateProposalMsg.salt)
    }

    result = await account0.execute({
        contractAddress: ethSigAuthAddress,
        entrypoint: "authenticate_update_proposal",
        calldata: CallData.compile(updateProposalCalldata as any),
    });

    console.log(result);


  }, 1000000);
});

function getRSVFromSig(sig: string) {
    if (sig.startsWith('0x')) {
      sig = sig.substring(2);
    }
    const r = `0x${sig.substring(0, 64)}`;
    const s = `0x${sig.substring(64, 64 * 2)}`;
    const v = `0x${sig.substring(64 * 2)}`;
    return { r, s, v };
  }

