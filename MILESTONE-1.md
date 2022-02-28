# Milestone 1

The first milestone includes 3 contracts (in red on the diagram below): A space contract holding votes and proposals, an authenticator contract approving signed messages for casting a vote or creating a proposal, and a voting strategy where 1 address is equal to 1 voting power. Execution, custom settings, or storage proof calculations are not part of this milestone.

![](https://user-images.githubusercontent.com/16245250/155883647-8f853411-bea9-4a73-bd69-2be850d4ffc9.png)

Source: https://whimsical.com/snapshot-x-design-proposal-Gy1y3P6zTs4rdE4cStaKW4

## Requirements

Here are the actions to cover in this milestone:
- Use auth contract as proxy
- Create a proposal
- Cast a vote
- Store votes and proposals

## Interfaces

### Space contract

This is the main contract, previously called "voting contract". The contract is responsible for storing proposals and votes, it also defines and stores parameters for the space.

#### Storage vars

- **voting_delay** = 600   
The time in seconds to wait between when a proposal is created and when the proposal voting period starts. 

- **voting_period** = 3600   
The duration of a proposal in seconds.

- **proposal_threshold** = 1   
The minimum amount of voting power that is required to submit a proposal.

- **voting_strategy** = 0x123...   
The voting strategy contract address that is used to calculate the voting power for each voter, the strategy will return 1 voting power for any address. 

- **auth** = 0x123...  
The authenticator contract address that is used to verify the addresses of voters and proposers.

- **next_proposal_nonce** = 1  
An increasing nonce to make the proposal id unique.

- **proposals** = TBD  
A mapping of proposals by ids with required information: execution_hash, start, end.

- **votes** = TBD  
A mapping of votes by proposal id with required information: address, choice, and voting power.

#### Functions

- **vote(address, proposal, choice)**  
Function to cast a vote, the payload is made up of the Ethereum address of the voter, the proposal id and the choice.

- **propose(address, execution_hash, metadata_uri)**   
Submit a new proposal. The **address** is an Ethereum address, **execution_hash** is a hash from EIP-712 that include execution details, here is an example https://gist.github.com/bonustrack/45fdb2f0235d6ad3ccffa328234379aa the **metadata_uri** is an URL string that leads to a JSON file which includes proposal metadata like title or body, this is similar to NFT tokenURI. It can be "ipfs://AbC..." or "https://..." URL.

### Voting strategy contract

The role of the voting strategy contract is to calculate voting power for a specific user. On this milestone we just need a voting strategy that always return 1 as voting power.

#### Functions

- **get_vp(address, at, data)**  
Returns the voting power for a specific address at a specific timestamp "at", "data" are the params required to run the voting power calculation, in milestone 1 it's just an empty array.

### Auth contract

The authenticator acts as a proxy to the space contract, the contract is here to validate that an address is authorized to do actions.

#### Functions

- **execute(target, data)**    
This function is a proxy to call another contract at address **target** with **data** as payload.


## Flows

Here is the flows for the actions. The assumption here is that all the transactions sent on StarkNet are not sent by the author of the vote or proposal itself but instead by an account that sponsors the transaction fee, ie the relayer (https://github.com/snapshot-labs/sx-relayer).

### Create a proposal

This is the flow to create a proposal.

- 1: User signs a proposal message on a test frontend, the message includes an **execution_hash** and **metadata_uri**.
- 2: This message and the signature are sent to the authenticator contract using **execute**, with the space contract address as **target** and the **sig**, **execution_hash**, and **metadata_uri** as **data**.
- 3: The authenticator contract will accept the tx regardless of the signature being correct or not and relay that tx to the defined space.
- 4: The space contract verifies that the tx comes from the authenticator contract address defined in the state variable **auth**.
- 5: The space contract stores the proposal in the variable **proposals**, this include an id defined by **next_proposal_nonce**, a **start** and **end** date defined using the current block timestamp, the space **delay** and **period**.
- 6: The Space contract increments **next_proposal_nonce** by 1. 

### Cast a vote

This is the flow to cast a vote.

- 1: User signs a proposal message on a test frontend, the message includes a **proposal** id and **choice**.
- 2: This message and the signature are sent to the authenticator contract using **execute**, with the space contract as **target** and the **sig**, **proposal**, and **choice** as **data**.
- 3: The authenticator contract accepts the tx regardless of the signature being correct or not and relays that tx to the defined space.
- 4: The space contract verifies that the tx comes from the authenticator contract address defined in the state variable **auth**.
- 5: The space contract verifies that the proposal exists and it's currently open for vote (between **start** and **end**).
- 6: The space contract obtains the user's voting power by calling the voting strategy contract.
- 7: The space contract stores the vote in the variable **votes** with his **address**, voting power **vp**, and **choice**.
