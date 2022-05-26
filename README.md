[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/snapshot-labs/sx-core/master/LICENSE)

# Snapshot X

Programmable governance on StarkNet. Refer to the [documentation](https://docs.snapshotx.xyz) for more information.

## Contracts Blueprint
```ml
contracts
├─ starknet
│   ├─ authenticators
│   │  ├─ EthTx.cairo — "Authenticate user via an Ethereum transaction"
│   │  └─ Vanilla.cairo — "Dummy authentication"
│   ├─ voting-strategies
│   │  ├─ SingleSlotProof.cairo — "Enables the use the contents of an Ethereum storage slot as voting power"
│   │  ├─ Vanilla.cairo — "Voting power of 1 for every user"
│   │  └─ Whitelist.cairo — "Predetermined voting power for members in a whitelist, otherwise zero"
│   ├─ execution-strategies
│   │  ├─ Vanilla.cairo — "Dummy execution"
│   │  └─ ZodiacRelayer.cairo — "Strategy to execute proposal transactions using an Ethereum Gnosis Safe"
│   ├─ interfaces
│   │  ├─ IAuthenticator.cairo — "Interface for all authenticators"
│   │  ├─ IExecutionStrategy.cairo — "Interface for all execution strategies"
│   │  └─ IVotingStrategy.cairo — "Interface for all voting strategies"
│   ├─ lib
│   │  ├─ array2d.cairo — "For handling 2 dimensional arrays"
│   │  ├─ choice.cairo — "The set of choices one can make for a vote"
│   │  ├─ eth_address.cairo — "Ethereum address type"
│   │  ├─ felt_to_uint256.cairo — "Convert a felt to a uint256"
│   │  ├─ hash_array.cairo — "Wrapper function for pedersen hashing arrays"
│   │  ├─ proposal.cairo — "Proposal metadata type"
│   │  ├─ proposal_info.cairo — "Proposal vote data type"
│   │  ├─ proposal_outcome.cairo — "The set of proposal outcomes"
│   │  ├─ slot_key.cairo — "Function to find the slot key for a slot in the Ethereum state"
│   │  ├─ vote.cairo.cairo — "User vote data type"
│   │  └─ words.cairo — "Small 64 bit word library"
│   ├─ test-contracts
│   │  ├─ Test_array2d.cairo 
│   │  ├─ Test_words.cairo 
│   │  └─ Test_words_to_uint256.cairo 
│   └─ Space.cairo - "The core contract for Snapshot X"
└─ ethereum 
    ├─ Interfaces
    │  └─ IStarknetCore.sol — "Authenticate user via an Ethereum transaction"
    ├─ StarkNetCommit
    │  └─ StarknetCommit.sol — "Authenticate user via an Ethereum transaction"
    ├─ SnapshotXZodiacModule
    │  ├─ ProposalRelayer.sol — "Authenticate user via an Ethereum transaction"
    │  ├─ SnapshotXL1Executor.sol — "Authenticate user via an Ethereum transaction"
    │  └─ deps.sol — "No authentication of users"
    └─ TestContracts
       ├─ MockStarknetMessaging.sol — "Authenticate user via an Ethereum transaction"
       ├─ NamedStorage.sol — "Authenticate user via an Ethereum transaction"
       └─ StarknetMessaging.sol — "No authentication of users"

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
python3.7 -m venv ~/cairo_venv
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

