[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/snapshot-labs/sx-core/master/LICENSE)

# Snapshot X

Programmable governance on StarkNet. Refer to the [documentation](https://docs.snapshotx.xyz) for more information.

## Contracts Blueprint
```ml
contracts
├─ starknet
│   ├─ Authenticators
│   │  ├─ EthTx.cairo — "Authenticate user via an Ethereum transaction"
│   │  ├─ EthSig.cairo — "Authenticate user via an Ethereum signature"
│   │  ├─ EthSigSessionKey.cairo — "Authenticate user via a Session key which has been authorized with an Ethereum signature"
│   │  ├─ EthTxSessionKey.cairo — "Authenticate user via a Session key which has been authorized with an Ethereum transaction"
│   │  ├─ StarkTx.cairo — "Authenticate user via a StarkNet transaction"
│   │  ├─ StarkSig.cairo — "Authenticate user via a Starknet signature"
│   │  └─ Vanilla.cairo — "Dummy authentication"
│   ├─ VotingStrategies
│   │  ├─ EthBalanceOf.cairo — "Voting power found from Ethereum token balances"
│   │  ├─ Vanilla.cairo — "Voting power of 1 for every user"
│   │  └─ Whitelist.cairo — "Predetermined voting power for members in a whitelist, otherwise zero"
│   ├─ ExecutionStrategies
│   │  ├─ Vanilla.cairo — "Dummy execution"
│   │  └─ EthereumRelayer.cairo — "Strategy to execute proposal transactions on Ethereum"
│   ├─ Interfaces
│   │  ├─ IAuthenticator.cairo — "Interface for all authenticators"
│   │  ├─ IExecutionStrategy.cairo — "Interface for all execution strategies"
│   │  └─ IVotingStrategy.cairo — "Interface for all voting strategies"
│   ├─ lib
│   │  ├─ array_utils.cairo — "Library for various array utilities"
│   │  ├─ choice.cairo — "The set of choices one can make for a vote"
│   │  ├─ eip712.cairo — "Library for Ethereum typed data signature verification"
│   │  ├─ eth_tx.cairo — "Libary for authenticating users via an Ethereum transaction"
│   │  ├─ execute.cairo — "contract call wrapper"
│   │  ├─ general_address.cairo — "Generic address type"
│   │  ├─ felt_utils.cairo — "Library for felt encoding/decoding"
│   │  ├─ proposal.cairo — "Proposal metadata type"
│   │  ├─ proposal_info.cairo — "Proposal vote data type"
│   │  ├─ proposal_outcome.cairo — "The set of proposal outcomes"
│   │  ├─ slot_key.cairo — "Library for finding EVM slot keys"
│   │  ├─ voting.cairo — "Core library that implements the logic for the space contract"
│   │  ├─ vote.cairo — "User vote data type"
│   │  ├─ session_key.cairo — "Library to handle session key logic"
│   │  ├─ stark_eip191.cairo — "Library for Starknet typed data signature verification"
│   │  ├─ single_slot_proof.cairo — "Library to enable values from the Ethereum state to be used for voting power"
│   │  └─ timestamp - "Library to handle timestamp to block number conversions within the single slot proof library"
│   ├─ SpaceAccount.cairo - "The base contract for each Snapshot X space"
│   └─ SpaceFactory.cairo - "Handles the deployment and tracking of Space contracts"
└─ ethereum 
    ├─ Interfaces
    │  └─ IStarknetCore.sol — "Interface of the StarkNet core contract"
    ├─ StarkNetCommit
    │  └─ StarknetCommit.sol — "Bridge contract to enable Ethereum transaction authentication"
    └─ ZodiacModule
       ├─ ProposalRelayer.sol — "Provides functionality for recieving proposal data from StarkNet"
       └─ SnapshotXL1Executor.sol — "Execute proposal transactions using a Gnosis Safe"
```

## Usage

### Clone repository:

```bash 
git clone https://github.com/snapshot-labs/sx-core.git
git submodule update --init --recursive
```
Note: The submodule included in the repo is the [Fossil](https://github.com/OilerNetwork/fossil) Storage Verifier

### Install Python and Yarn requirements: 

```bash
python3.9 -m venv ~/cairo_venv
source ~/cairo_venv/bin/activate
pip3 install -r requirements.txt
yarn
```

### Compile all contracts:

```bash
yarn compile
# You can also use yarn compile:l1 to just compile solidity contracts
# or yarn compile:l2 to just compile cairo contracts
```

### Deploy to Alpha Goerli:

```bash 
yarn deploy:goerli
```
Will deploy an example space contract and a set of authenticators, voting strategies and execution strategies to the alpha goerli testnet. 

### Testing

Tests are separated into three categories:

- Ethereum tests in `tests/ethereum`: Tests for our solidity contracts
- Starknet tests in `tests/starknet`: Tests for our cairo contracts
- Cross chain tests in `tests/crosschain`: Tests that will cover interaction between solidity and cairo contracts.

To run these tests locally: 

#### Install and run [StarkNet Devnet](https://github.com/Shard-Labs/starknet-devnet) (In a separate terminal):
```bash
yarn chain:l2
```

#### Run an ethereum hardhat node (In a separate terminal)

```bash
yarn chain:l1
```

#### Run tests:
```bash
yarn test:l1
yarn test:l2 
yarn test:crosschain
```

## DISCLAIMER: STILL IN DEVELOPMENT

This project is still under heavy development. Feel free to contact us on [Discord](https://discord.snapshot.org)!

## License

Snapshot X contracts are open-source software licensed under the © [MIT license](LICENSE).

