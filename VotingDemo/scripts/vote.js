const { defaultProvider, stark } = require('starknet');
const { getSelectorFromName } = stark;

async function main() {

    const VOTING_CONTRACT_ADDRESS = 
    "0x0180abab6c7c3983e886bd4f8ca6090e068cf10f14be6ae9919e7b0c654d28c1";


    //The owner of the voting contract 
    const ACCOUNT_CONTRACT_ADDRESS =
    "0x069053b14d69a52aebc20833452df0da83ed20a43396ae7bb922b6eeba56c9de";


    //create proposal, emits event containing proposal id and proposer address
    var addTokenResponse = await defaultProvider.addTransaction({
    type: "INVOKE_FUNCTION",
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("propose"),
    calldata: ["1234", "5678"],
    });
    console.log(addTokenResponse);   



    //cast vote, emits an event containing vote info
    var addTokenResponse = await defaultProvider.addTransaction({
    type: "INVOKE_FUNCTION",
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("vote"),
    calldata: ["60265779274270434537323828408977526710079971372926889746684550312238229785", "33333", "2", "7777"],
    });
    console.log(addTokenResponse);  



    //get proposal id so that you can query the contract for vote info
    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_proposal_id"),
    calldata: ["1234", "5678"],
    });
    console.log(out.result[0])



    //Gets the number of votes for each of the 3 choices for the given proposal id: 
    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_num_choice"),
    calldata: ["60265779274270434537323828408977526710079971372926889746684550312238229785", "1"],
    });
    console.log(out.result[0])
  
    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_num_choice"),
    calldata: ["60265779274270434537323828408977526710079971372926889746684550312238229785", "2"],
    });
    console.log(out.result[0])

    var out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName("get_num_choice"),
    calldata: ["60265779274270434537323828408977526710079971372926889746684550312238229785", "3"],
    });
    console.log(out.result[0])

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });