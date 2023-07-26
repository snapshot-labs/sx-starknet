import fs from "fs";
import dotenv from 'dotenv';
import { Provider, Account, Contract, CallData, cairo}  from "starknet";
import { ethers } from "ethers";

import { domain, Propose, proposeTypes } from "./types";

dotenv.config();

const pk = process.env.PRIVATE_KEY || '';

async function main() {
    const signer = new ethers.Wallet(pk);

    // connect provider
    const provider = new Provider({ sequencer: { baseUrl:"http://127.0.0.1:5050"} });
    console.log('provider=', provider);
    // new Open Zeppelin account v0.5.1 :
        // Generate public and private key pair.
    const privateKey0 = "0xe3e70682c2094cac629f6fbed82c07cd";
    const address0 = "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a";
    const account0 = new Account(provider, address0, privateKey0);

    const ethSigAuthAddress = "0x2b5419778c3501eb0b447081f0e1211cf5d6d5c8c4356bc414dbb65710bfa57";

    const {abi: ethSigAuthAbi} = await provider.getClassAt(ethSigAuthAddress);
    const ethSigAuth = new Contract(ethSigAuthAbi, ethSigAuthAddress, provider);

    const result = await account0.execute({
        contractAddress: ethSigAuthAddress,
        entrypoint: "authenticate_propose",
        calldata: CallData.compile({
            r: cairo.uint256(1),
            s: cairo.uint256(2),
            v: cairo.uint256(3),
            target: "0x0000000000000000000000000000000000001235",
            author: signer.address,
            execution_strategy: {
                addr: "0x0000000000000000000000000000000000001234",
                params: [1,2,3,4]
            },
            user_proposal_validation_params: [1,2,3,4],
            salt: cairo.uint256(0)
        })
    })

    console.log(result);


    const proposeMessage: Propose = {
        space: "0x0000000000000000000000000000000000001234",
        author: signer.address,
        executionStrategy: {
            addr: "0x0000000000000000000000000000000000001234",
            params: "0x1234"
        },
        userProposalValidationParams: "0x1234",
        salt: "0x0"
    }

    const sig = await signer.signTypedData(domain, proposeTypes, proposeMessage);

    console.log(sig);


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
