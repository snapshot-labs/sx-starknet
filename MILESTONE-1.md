# Milestone 1

The first milestone include 3 contracts (in red on the diagram below), a space contract holding votes and proposals, an auth contract approving signed messages for cast vote or proposal, and a voting strategy where 1 address equal to 1 voting power. Execution, custom settings or storage proof calculations are not part of this milestone.

![](https://user-images.githubusercontent.com/16245250/155883647-8f853411-bea9-4a73-bd69-2be850d4ffc9.png)

Source: https://whimsical.com/snapshot-x-design-proposal-Gy1y3P6zTs4rdE4cStaKW4

## Requirements

Here is actions to cover in this milestone:
- Use auth contract as proxy
- Create a proposal
- Cast a vote
- Store votes and proposals

## Interfaces

### Space contract

This is the main contract, previously called "voting contract" the contract is responsible to store proposals and votes, it also define parameters.

#### Storage vars

- **voting_delay** = 600   
The time in second to wait between a proposal is created and the proposal voting period start. 

- **voting_period** = 3600   
The duration of a proposal in second.

- **proposal_threshold** = 1   
The minimum amount of voting power required to submit a proposal.

- **voting_strategy** = 0x123...   
Single contract address on StarkNet to calculate voting power, the strategy return 1 voting power for any address. 

- **auth** = 0x123...  
Authenticator contract address used to verify voters and proposers address.

- **next_proposal_nonce** = 1  
We keep an increasing nonce to make proposal id unique.

- **proposals** = TBD  
Mapping of proposals by ids with required informations: execution_hash, start, end.

- **votes** = TBD  
Mapping of votes by proposal id with required informations: address, choice, voting power.

#### Functions

- **vote(address, proposal, choice)**  
Function to cast a vote, payload include the address of the voter, the proposal id and the choice.

- **propose(execution_hash, metadata_uri)**   
Submit a new proposal. The execution hash is a hash from EIP-712 that include execution details, here is an example https://gist.github.com/bonustrack/45fdb2f0235d6ad3ccffa328234379aa the metadata_uri is an URL string that lead to a JSON file which include proposal metadata like title or body, this is similar than NFT tokenURI it can be "ipfs://AbC..." or "https://..." URL.

### Voting strategy contract

The role of the voting strategy contract is to calculate voting power for a specific user. On this milestone we just need a voting strategy that always return 1 as voting power.

#### Functions

- **get_vp(address, at)**  
Return the voting power for a specific address at a specific timestamp "at".

### Auth contract

The authenticator act as a proxy to the space contract, the contract is here to validate an address is legit to do actions.

#### Functions

- **execute(target, data)**    
This function is a proxy to call another contract "target" with "data" as payload.


## Flows

Here is the flows for the actions, the assumption here is all the transactions sent on StarkNet are not sent by the author of the vote or proposal itself but instead by an account that sponsor transaction fee, the relayer (https://github.com/snapshot-labs/sx-relayer).

### Create a proposal

This is the flow to create a proposal.

- 1: User sign a proposal message on a test frontend, the message include an **execution_hash** and **metadata_uri**.
- 2: This message and the signature are sent to the authenticator contract using **execute**, with the space contract as **target** and with the **sig**, **execution_hash** and **metadata_uri** as **data**.
- 3: The authenticator contract accept the tx regardless of the signature being correct or not and relay that tx to the defined space.
- 4: The space contract verify that the tx come from the authenticator contract address defined in the state variable **auth**.
- 5: The space contract store the proposal in the variable **proposals**, this include an id defined by **next_proposal_nonce**, a **start** and **end** date defined using the current block timestamp, the space **delay** and **period**.
- 6: Space contract increment **next_proposal_nonce** by 1. 

### Cast a vote

This is the flow to cast a vote.

- 1: User sign a proposal message on a test frontend, the message include an **proposal** id and **choice**.
- 2: This message and the signature are sent to the authenticator contract using **execute**, with the space contract as **target** and with the **sig**, **proposal** and **choice** as **data**.
- 3: The authenticator contract accept the tx regardless of the signature being correct or not and relay that tx to the defined space.
- 4: The space contract verify that the tx come from the authenticator contract address defined in the state variable **auth**.
- 5: The space contract verify that the proposal exist and it's currently open for vote (between **start** and **end**).
- 6: The space contract verify the user voting power by calling the voting strategy contract.
- 7: The space contract store the vote in the variable **votes** with his **address**, voting power **vp** and **choice**.
