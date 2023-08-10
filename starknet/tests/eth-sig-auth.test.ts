import fs from 'fs';
import { ethers } from "ethers";
import { Provider, Account, Contract, CallData, cairo, shortString, json, Calldata } from 'starknet';
import { Propose, proposeTypes, EthereumSigProposeCalldata } from "./types";

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

    console.log("addr: ", signer.address);

    // console.log(ethers.TypedDataEncoder.from(proposeTypes).hash(proposeMsg));

    console.log("propose digest ts: ", ethers.TypedDataEncoder.hash(domain, proposeTypes, proposeMsg));

    const sig = await signer.signTypedData(domain, proposeTypes, proposeMsg);
    console.log(sig);
    const { r, s, v } = getRSVFromSig(sig);
    console.log(r, s, v);

    const proposeCalldata = {
        r: cairo.uint256(r),
        s: cairo.uint256(s),
        v: v,
        space: proposeMsg.space,
        author: proposeMsg.author,
        executionStrategy: proposeMsg.executionStrategy,
        userProposalValidationParams: proposeMsg.userProposalValidationParams,
        salt: cairo.uint256(proposeMsg.salt)
    }

    let out = await ethSigAuth.call("get_hash", CallData.compile(proposeCalldata as any), {parseResponse: false});

    console.log('propose digest: ', out);

    const result = await account0.execute({
        contractAddress: ethSigAuthAddress,
        entrypoint: "authenticate_propose",
        calldata: CallData.compile(proposeCalldata as any),
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

