import fs from "fs";
import dotenv from 'dotenv';
import { Provider, Account, Contract, CallData, Calldata, typedData, cairo}  from "starknet";
import { proposeTypes, Propose, StarknetSigProposeCalldata, domain } from "./types";

dotenv.config();

const pk = process.env.PRIVATE_KEY || '';

async function main() {
    const provider = new Provider({ sequencer: { baseUrl:"http://127.0.0.1:5050"} });

    const privateKey0 = "0xe3e70682c2094cac629f6fbed82c07cd";
    const address0 = "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a";
    const publickey0 = "0x7e52885445756b313ea16849145363ccb73fb4ab0440dbac333cf9d13de82b9"
    const account0 = new Account(provider, address0, privateKey0);
    
    const starkSigAuthAddress = "0x2baf1877b1388d8421485c8cb419b37ebce3096e323c4ef6b3c979a8a30917e";

    const {abi: starkSigAuthAbi} = await provider.getClassAt(starkSigAuthAddress);
    const starkSigAuth = new Contract(starkSigAuthAbi, starkSigAuthAddress, provider);

    const proposeMsg: Propose = {
        space: "0x0000000000000000000000000000000000007777",
        author: "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a",
        executionStrategy: {
            address: "0x0000000000000000000000000000000000001234",
            params: ["0x5", "0x6", "0x7", "0x8"]
        },
        userProposalValidationParams: ["0x1", "0x2", "0x3", "0x4"],
        salt: "0x0"
    }

    const proposeData: typedData.TypedData = {
        types: proposeTypes,
        primaryType: "Propose",
        domain: domain,
        message: proposeMsg as any
    }

    const msgHash = typedData.getMessageHash(proposeData, address0);

    console.log('msgHash=', msgHash);

    const signature2 = await account0.signMessage(proposeData) as any;

    const proposeCalldata: StarknetSigProposeCalldata = {
        r: signature2.r,    
        s: signature2.s,
        ...proposeMsg,
        public_key: publickey0
    }
    
    const result = await account0.execute({
        contractAddress: starkSigAuthAddress,
        entrypoint: "authenticate_propose",
        calldata: CallData.compile(proposeCalldata as any)
    })
    console.log(result);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
