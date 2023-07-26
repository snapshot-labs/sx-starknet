import fs from "fs";
import { Account, constants, ec, json, stark, Provider, hash, CallData } from "starknet";

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
    const compiledTestSierra = json.parse(fs.readFileSync( "starknet/target/dev/sx_EthSigAuthenticator.sierra.json").toString( "ascii"));
    const compiledTestCasm = json.parse(fs.readFileSync( "starknet/target/dev/sx_EthSigAuthenticator.casm.json").toString( "ascii"));
    
    const deployResponse = await account0.declareAndDeploy({ contract: compiledTestSierra, casm: compiledTestCasm });



    // const OZaccountClassHash = "0x2794ce20e5f2ff0d40e632cb53845b9f4e526ebd8471983f7dbd355b721d5a";
    // // Calculate future address of the account
    // const OZaccountConstructorCallData = CallData.compile({ publicKey: starkKeyPub });
    // const OZcontractAddress = hash.calculateContractAddressFromHash(
    //     starkKeyPub,
    //     OZaccountClassHash,
    //     OZaccountConstructorCallData,
    //     0
    // );
    // console.log('Precalculated account address=', OZcontractAddress);

    // const OZaccount = new Account(provider, OZcontractAddress, privateKey);

    // const { transaction_hash, contract_address } = await OZaccount.deployAccount({
    //     classHash: OZaccountClassHash,
    //     constructorCalldata: OZaccountConstructorCallData,
    //     addressSalt: starkKeyPub
    // });

    // await provider.waitForTransaction(transaction_hash);
    // console.log('✅ New OpenZeppelin account created.\n   address =', contract_address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
