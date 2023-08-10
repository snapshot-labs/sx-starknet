import fs from "fs";
import dotenv from 'dotenv';
import { Provider, Account, Contract, CallData, cairo}  from "starknet";
import { ethers } from "ethers";

dotenv.config();

const pk = process.env.PRIVATE_KEY || '';

async function main() {
    // console.log(ethers.solidityPackedKeccak256(["bytes"], ["0x75f52ba42565df4ccdeb93be4cdd287b75056e993a11ce5c247d5463fcf8c17d00000000000000000000000000000000000000000000000000000000000012340000000000000000000000002842c82e20ab600f443646e1bc8550b44a513d821ec7f11b73631c07316dfc6261e4ee3f46b3a51380f5bcb39c46c16e88da8a5656570de287d73cd1cb6092bb8fdee6173974955fdef345ae579ee9f475ea74320000000000000000000000000000000000000000000000000000000000000007"]));
    // console.log(ethers.solidityPackedKeccak256(["bytes"], ["0x11"]));

    
    // console.log(ethers.solidityPackedKeccak256(["string"], ["Propose(uint256 authenticator,uint256 space,address author,Strategy executionStrategy,uint256[] userProposalValidationParams,uint256 salt)Strategy(uint256 address,uint256[] params)"]));
    
    // console.log(ethers.solidityPackedKeccak256(["string"], ["Strategy(uint256 address,uint256[] params)"]));

    // console.log(ethers.solidityPackedKeccak256(["string"], ["EIP712Domain(uint256 chainId,bytes32 salt)"]));

    console.log(ethers.solidityPackedKeccak256(["bytes"], ["0x1901685b35df84e62b77a50997a23952c14aab06bfc46ade2227c2a0d7152c10af3e273fa831aaa8a2f342cf0e31b2534dfc6dd425e4175b05c47a1bc3fc7cf578d6"]));
  
    console.log(ethers.solidityPackedKeccak256(["bytes"], ["0x1901685b35df84e62b77a50997a23952c14aab06bfc46ade2227c2a0d7152c10af3e273fa831aaa8a2f342cf0e31b2534dfc6dd425e4175b05c47a1bc3fc7cf578d6000000000000000000000000000000000000000000000000000000000000"]));

    // 0x1901685b35df84e62b77a50997a23952c14aab06bfc46ade2227c2a0d7152c10af3ebd1e2b19fc94f6ba7a337141d462dbefc3d84a8c9cdec382c309a36ebd3df7fd 


    // 0x75f52ba42565df4ccdeb93be4cdd287b75056e993a11ce5c247d5463fcf8c17d00000000000000000000000000000000000000000000000000000000000012340000000000000000000000002842c82e20ab600f443646e1bc8550b44a513d821ec7f11b73631c07316dfc6261e4ee3f46b3a51380f5bcb39c46c16e88da8a5656570de287d73cd1cb6092bb8fdee6173974955fdef345ae579ee9f475ea74320000000000000000000000000000000000000000000000000000000000000007
    
    // 0x75f52ba42565df4ccdeb93be4cdd287b75056e993a11ce5c247d5463fcf8c17d00000000000000000000000000000000000000000000000000000000000012340000000000000000000000002842c82e20ab600f443646e1bc8550b44a513d821ec7f11b73631c07316dfc6261e4ee3f46b3a51380f5bcb39c46c16e88da8a56bc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a0000000000000000000000000000000000000000000000000000000000000007
    // const signer = new ethers.Wallet(pk);

    // // connect provider
    // const provider = new Provider({ sequencer: { baseUrl:"http://127.0.0.1:5050"} });
    // // new Open Zeppelin account v0.5.1 :
    //     // Generate public and private key pair.
    // const privateKey0 = "0xe3e70682c2094cac629f6fbed82c07cd";
    // const address0 = "0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a";
    // const account0 = new Account(provider, address0, privateKey0);
    
    // const ethSigAuthAddress = "0x20f5290df17c81de847e366ab4dd7cb0256bf010940b79e503a173e75cf73ca";

    // const {abi: ethSigAuthAbi} = await provider.getClassAt(ethSigAuthAddress);
    // const ethSigAuth = new Contract(ethSigAuthAbi, ethSigAuthAddress, provider);

    // const result = await account0.execute({
    //     contractAddress: ethSigAuthAddress,
    //     entrypoint: "authenticate_propose",
    //     calldata: CallData.compile({
    //         r: cairo.uint256(1),
    //         s: cairo.uint256(2),
    //         v: cairo.uint256(3),
    //         target: "0x0000000000000000000000000000000000001235",
    //         author: signer.address,
    //         execution_strategy: {
    //             addr: "0x0000000000000000000000000000000000001234",
    //             params: [1,2,3,4]
    //         },
    //         user_proposal_validation_params: [1,2,3,4],
    //         salt: cairo.uint256(0)
    //     })
    // })

    // console.log(result);


    // const proposeMessage: Propose = {
    //     space: "0x0000000000000000000000000000000000001234",
    //     author: signer.address,
    //     executionStrategy: {
    //         addr: "0x0000000000000000000000000000000000001234",
    //         params: "0x1234"
    //     },
    //     userProposalValidationParams: "0x1234",
    //     salt: "0x0"
    // }

    // const sig = await signer.signTypedData(domain, proposeTypes, proposeMessage);

    // console.log(sig);


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
