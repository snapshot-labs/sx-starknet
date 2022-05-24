[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/snapshot-labs/sx-core/master/LICENSE)

# Snapshot X

Programmable governance on StarkNet.

#### [Documentation](https://docs.snapshotx.xyz)


## Usage

### Blueprint
```ml
contracts
├─ starknet
│   ├─ authenticators
│   │  ├─ eth_tx.cairo — "Authenticate user via an Ethereum transaction"
│   │  └─ vanilla.cairo — "No authentication of users"
│   ├─ execution_strategies
│   │  ├─ vanilla.cairo — "No execution"
│   │  └─ zodiac_relayer.cairo — "Strategy to execute proposal transactions using an Ethereum Gnosis Safe"
│   ├─ interfaces
│   │  ├─ i_authenticator.cairo — "..."
│   │  ├─ i_execution_strategy.cairo — "..."
│   │  └─ i_voting_strategy.cairo — "Permissionless Broker for ArtBlocks Minting using Flashbot Searchers"
│   ├─ lib
│   │  ├─ array2d.cairo — "..."
│   │  ├─ choice.cairo — "..."
│   │  ├─ eth_address.cairo — "..."
│   │  ├─ felt_to_uint256.cairo — "..."
│   │  ├─ hash_array.cairo — "..."
│   │  ├─ proposal.cairo — "..."
│   │  ├─ proposal_info.cairo — "..."
│   │  ├─ proposal_outcome.cairo — "..."
│   │  ├─ slot_key.cairo — "..."
│   │  ├─ vote.cairo.cairo — "..."
│   │  ├─ words.cairo — "..."
│   │  └─ words64_to_uint256.cairo — "Permissionless Broker for ArtBlocks Minting using Flashbot Searchers"
│   ├─ test_contracts
│   │  ├─ test_array2d.cairo — "..."
│   │  ├─ test_words.cairo — "..."
│   │  └─ test_words64_to_uint256.cairo — "Permissionless Broker for ArtBlocks Minting using Flashbot Searchers"
│   ├─ voting_strategies
│   │  ├─ single_slot_proof.cairo — "..."
│   │  ├─ vanilla.cairo — "..."
│   │  └─ whitelist.cairo — "Permissionless Broker for ArtBlocks Minting using Flashbot Searchers"
│   └─ space.cairo
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

