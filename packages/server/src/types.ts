export const domain = {
  name: 'snapshot-x',
  version: 1,
  chainId: 'starknet', // Expect a type "uint256" here, following EIP-155
  verifyingContract: '0x335c0d227...' // StarkNet contract where to send message (voting contract), expect type "address"
};

export const proposalTypes = {
  Proposal: [
    { name: 'executionHash', type: 'bytes32' }, // Hash of EIP-712 message that contain execution details
    { name: 'metadataHash', type: 'bytes32' } // Hash of EIP-712 message that contain: title, body
  ]
};

export const voteTypes = {
  Vote: [
    { name: 'proposal', type: 'bytes32' }, // Hash of EIP-712 proposal message
    { name: 'choice', type: 'uint32' } // Possible choice: 0 = against, 1 = for, 2 = abstain
  ]
};
