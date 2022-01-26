const { defaultProvider, stark } = require('starknet');
const { getSelectorFromName } = stark;


async function main() {

    //deploy consumeTx.cairo contract to alpha-goerli via: npx hardhat starknet-deploy --starknet-network alpha-goerli
    const CONTRACT_ADDRESS =
    "0x03c2316b129fd6333d861157087ad265f5093686984b601be1ff742645e76269";

    //Example Transactions and calls: 

    const out = await defaultProvider.callContract({
    contract_address: CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_next_id"),
    calldata: [],
    });
    console.log(out.result[0])

    //takes a minute or two to be accepted on L2 
    const addTokenResponse = await defaultProvider.addTransaction({
    type: "INVOKE_FUNCTION",
    contract_address: CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("receive_tx"),
    calldata: ["2", "4"],
    });
    console.log(addTokenResponse);

    const out3 = await defaultProvider.callContract({
    contract_address: CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_tx_params"),
    calldata: ["0"],
    });
    const param1 = out3.result[0];
    const param2 = out3.result[1];
    console.log('param1: ', param1);
    console.log('param2: ', param2);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });