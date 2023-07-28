import fs from "fs";
import dotenv from 'dotenv';
import { Provider, Account, Contract, CallData, Calldata, typedData, cairo}  from "starknet";
import { typedDataPropose } from "./types";

dotenv.config();

const pk = process.env.PRIVATE_KEY || '';

async function main() {
    // connect provider
    const provider = new Provider({ sequencer: { baseUrl:"http://127.0.0.1:5050"} });
    // new Open Zeppelin account v0.5.1 :
        // Generate public and private key pair.
    const privateKey0 = "0xe3e70682c2094cac629f6fbed82c07cd";
    const address0 = "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a";
    const account0 = new Account(provider, address0, privateKey0);

    const starkSigAuthAddress = "0x14f48340c1ee431755c004365b58e92e69003495af214cf90c3603338e7e945";

    const {abi: starkSigAuthAbi} = await provider.getClassAt(starkSigAuthAddress);
    const starkSigAuth = new Contract(starkSigAuthAbi, starkSigAuthAddress, provider);

    const msgHash = typedData.getMessageHash(typedDataPropose, address0);

    console.log('msgHash=', msgHash);

    const signature2 = await account0.signMessage(typedDataPropose);

    console.log('signature2=', signature2);

    // console.log(starkSigAuth.abi[2]);
    const specialParameters: Calldata = CallData.compile({
                r: 1,
                s: 2,
                target: "0x0000000000000000000000000000000000007777",
                author: address0,
                execution_strategy: {
                    addr: "0x0000000000000000000000000000000000001234",
                    params: [5,6,7,8]
                },
                user_proposal_validation_params: [1,2,3,4],
                salt: 0
            });
    
    // console.log(specialParameters);
        
    const out = await starkSigAuth.call("propose_hash", specialParameters, {parseResponse: false});

    console.log('out=', out);


    // // const result = await account0.execute({
    // //     contractAddress: starkSigAuthAddress,
    // //     entrypoint: "propose_hash",
    // //     calldata: CallData.compile({
    // //         r: 1,
    // //         s: 2,
    // //         target: "0x0000000000000000000000000000000000001235",
    // //         author: address0,
    // //         execution_strategy: {
    // //             addr: "0x0000000000000000000000000000000000001234",
    // //             params: [1,2,3,4]
    // //         },
    // //         user_proposal_validation_params: [1,2,3,4],
    // //         salt: 0
    // //     })
    // // })
    // // console.log(result);


    // // const proposeMessage: Propose = {
    // //     space: "0x0000000000000000000000000000000000001234",
    // //     author: signer.address,
    // //     executionStrategy: {
    // //         addr: "0x0000000000000000000000000000000000001234",
    // //         params: "0x1234"
    // //     },
    // //     userProposalValidationParams: "0x1234",
    // //     salt: "0x0"
    // // }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });