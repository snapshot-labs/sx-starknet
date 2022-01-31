const { defaultProvider, stark } = require('starknet');
const { getSelectorFromName } = stark;

async function main() {

    const VOTING_CONTRACT_ADDRESS = 
    "0x0414130848ed5100d0c3bb0dafc3cf2a6de63b4ea49862ee5c38ccec2145cbda";

    const ACCOUNT_CONTRACT_ADDRESS =
    "0x069053b14d69a52aebc20833452df0da83ed20a43396ae7bb922b6eeba56c9de";


    //cast vote, emits an event containing vote info
    // const addTokenResponse = await defaultProvider.addTransaction({
    // type: "INVOKE_FUNCTION",
    // contract_address: VOTING_CONTRACT_ADDRESS,
    // entry_point_selector: getSelectorFromName("vote"),
    // calldata: ["0", "1234", "2", "5678"],
    // });
    // console.log(addTokenResponse);  

    //Gets the number of votes for each of the 3 choices: 

    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_num_choice"),
    calldata: ["0", "1"],
    });
    console.log(out.result[0])
  
    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_num_choice"),
    calldata: ["0", "2"],
    });
    console.log(out.result[0])

    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_num_choice"),
    calldata: ["0", "3"],
    });
    console.log(out.result[0])


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
