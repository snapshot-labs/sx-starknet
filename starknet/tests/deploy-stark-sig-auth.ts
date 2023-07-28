import fs from "fs";
import dotenv from 'dotenv';
import { Account, json, Provider, CallData, Calldata } from "starknet";

dotenv.config();

const pk = process.env.PRIVATE_KEY || '';

async function main() {
    // connect provider
    const provider = new Provider({ sequencer: { baseUrl:"http://127.0.0.1:5050"} });
    console.log('provider=', provider);
    // new Open Zeppelin account v0.5.1 :
        // Generate public and private key pair.
    const privateKey0 = "0xe3e70682c2094cac629f6fbed82c07cd";
    const address0 = "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a";
    const account0 = new Account(provider, address0, privateKey0);

    // Declare & deploy Test contract in devnet
    const compiledContractSierra = json.parse(fs.readFileSync( "starknet/target/dev/sx_StarkSigAuthenticator.sierra.json").toString( "ascii"));
    const compiledContractCasm = json.parse(fs.readFileSync( "starknet/target/dev/sx_StarkSigAuthenticator.casm.json").toString( "ascii"));

    const deployResponse = await account0.declareAndDeploy({ contract: compiledContractSierra, casm: compiledContractCasm});
    console.log('deployResponse=', deployResponse);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });