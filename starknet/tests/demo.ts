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

    console.log(ethers.solidityPackedKeccak256(["string"], ["Propose(uint256 authenticator,uint256 space,address author,Strategy executionStrategy,uint256[] userProposalValidationParams,uint256[] metadataURI,uint256 salt)Strategy(uint256 address,uint256[] params)"]));

    console.log(ethers.solidityPackedKeccak256(["string"], ["Vote(uint256 authenticator,uint256 space,address voter,uint256 proposalId,uint256 choice,IndexedStrategy[] userVotingStrategies,uint256[] metadataURI)IndexedStrategy(uint256 index,uint256[] params)"]));

    console.log(ethers.solidityPackedKeccak256(["string"], ["UpdateProposal(uint256 authenticator,uint256 space,address author,uint256 proposalId,Strategy executionStrategy,uint256[] metadataURI,uint256 salt)Strategy(uint256 address,uint256[] params)"]));


    "0x40d2edfc30a6c2f3db15e88660bc1a9272b77b619e97d1b0120af84bb49b15a20214749cacc22fde96d1e23ad383f7c08e54e251544706ae96ad6eec70c310f100000000000000000000000000000000000000000000000000000000000012340000000000000000000000002842c82e20ab600f443646e1bc8550b44a513d820000000000000000000000000000000000000000000000000000000000000001c585e6e9067167fe339d107cf54212a641a517b3f4c9cdec80cf43382365059a0000000000000000000000000000000000000000000000000000000000000007"
    "0x40d2edfc30a6c2f3db15e88660bc1a9272b77b619e97d1b0120af84bb49b15a20214749cacc22fde96d1e23ad383f7c08e54e251544706ae96ad6eec70c310f100000000000000000000000000000000000000000000000000000000000012340000000000000000000000002842c82e20ab600f443646e1bc8550b44a513d82"

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
