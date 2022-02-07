const { defaultProvider, stark } = require('starknet');
const { getSelectorFromName } = stark;

async function main() {
  const VOTING_CONTRACT_ADDRESS =
    '0x05a880858035c9f5234f4bb97e903b0e1b5cd4c5ae0e59d0b7087168b319c503';

  // create proposal, emits event containing proposal id and proposer address
  let addTokenResponse = await defaultProvider.addTransaction({
    type: 'INVOKE_FUNCTION',
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName('propose'),
    calldata: ['1234', '5678'],
  });
  console.log(addTokenResponse);

  // vote
  addTokenResponse = await defaultProvider.addTransaction({
    type: 'INVOKE_FUNCTION',
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName('vote'),
    calldata: [
      '60265779274270434537323828408977526710079971372926889746684550312238229785',
      '33333',
      '2',
      '7777',
    ],
  });
  console.log(addTokenResponse);

  // Gets the number of votes for each of the 3 choices:

  // Gets the number of votes for each of the 3 choices for the given proposal id:
  let out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName('get_num_choice'),
    calldata: ['60265779274270434537323828408977526710079971372926889746684550312238229785', '1'],
  });
  console.log(out.result[0]);

  out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName('get_num_choice'),
    calldata: ['60265779274270434537323828408977526710079971372926889746684550312238229785', '2'],
  });
  console.log(out.result[0]);

  out = await defaultProvider.callContract({
    contract_address: VOTING_CONTRACT_ADDRESS,
    entry_point_selector: getSelectorFromName('get_num_choice'),
    calldata: ['60265779274270434537323828408977526710079971372926889746684550312238229785', '3'],
  });
  console.log(out.result[0]);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
