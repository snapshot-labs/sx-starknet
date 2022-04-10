<div align="center">
    <img src="https://raw.githubusercontent.com/snapshot-labs/snapshot/develop/public/icon.svg" height="70" alt="Snapshot Logo">
    <h1>Snapshot X</h1>
    <strong>Snapshot X is an on-chain multi-governance client deployed on <a href="https://starkware.co/starknet/">Starknet</a>.</strong>
</div>
<br>
<div align="center">
    <img src="https://img.shields.io/github/commit-activity/w/snapshot-labs/snapshot-x" alt="GitHub commit activity">
    <a href="https://github.com/snapshot-labs/snapshot-x/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22">
        <img src="https://img.shields.io/github/issues/snapshot-labs/snapshot-x/help wanted" alt="GitHub issues help wanted">
    </a>
    <a href="https://telegram.snapshot.org">
        <img src="https://img.shields.io/badge/Telegram-white?logo=telegram" alt="Telegram">
    </a>
    <a href="https://discord.snapshot.org">
        <img src="https://img.shields.io/discord/707079246388133940.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2" alt="Discord">
    </a>
    <a href="https://twitter.com/SnapshotLabs">
        <img src="https://img.shields.io/twitter/follow/SnapshotLabs?label=SnapshotLabs&style=flat&logo=twitter&color=1DA1F2" alt="Twitter">
    </a>
</div>

## Snapshot X

Snapshot X is a voting framework built on StarkNet, the layer 2 ZK-Rollup. It will allow any DAO to run their governance on-chain on layer 2 and execute transactions on Ethereum.

### Code overview

Snapshot X is designed to be as modular as possible. Let's go over the core contracts that every DAO will need:

#### Space contract

The [space](contracts/starknet/space/space.cairo) is THE core contract: it's in charge of tracking proposals, votes, and other general settings.
To deploy a new space, you will need to provide:
- `voting_delay`: The delay between when a proposal is created, and when the voting starts. A `voting_delay` of 0 means that as soon as the proposal is created, anyone can vote. A `voting_delay` of 3600 means that voting will start `3600` seconds after the proposal is created.
- `voting_duration`: The duration of the voting period, i.e. how long people will be able to vote for a proposal.
- `proposal_threshold`: The amount of voting power needed to be able to create a new proposal. Used to avoid having anyone be able to create a proposal.
- `voting_strategies`: A list of accepted voting strategy contracts. A voting strategy contract is used to determine the voting power of a user. More information in the [Voting Strategy](#Voting-Strategies) section.
- `authenticators`: A list of accepted authenticators. Authenticators are used to authenticate users. For more information, refer to the [Authenticators](#Authenticators) section.

Once a space has been created, users can create new proposals by calling the `propose` method (provided the caller has at least `proposal_threshold` voting power). Users don't directly interact with the `space` contract, but use one of the `authenticator` as a proxy. Once a proposal has been created, and the `voting_delay` has elapsed, users can then vote for the proposal (once again, using an `authenticator` as a proxy). Once the `voting_duration` has passed, votes are closed, and anyone can call `finalize_proposal` (this time, directly on the space contract!): this will finalize the proposal, count the votes for/against/abstain, and call the execution contract. More information about the execution in the [Execution Contract](#Execution-Contract) section.

#### Voting Strategies

Voting strategy contracts are the contracts used to determine the voting power of a user. The most common example is using the erc20 token balance of a user to determine his voting power. But we could imagine other voting strategies: owning a specific NFT, owning NFT of collection X and another NFT of collection Y, having participated in protocol xyz... the possibilities are endless! We provide the [single_slot_proof](contracts/starknet/strategies/single_slot_proof.cairo) which allows classic ERC20 and ERC721 balances on L1 (thanks to [fossil](https://github.com/OilerNetwork/fossil)) to be used as voting power, but feel free to create your own strategies! The interface of a strategy can be found [here](contracts/starknet/strategies/interface.cairo).

#### Authenticators

Authenticators are the contracts in charge of authenticating users. This repository provides two useful authenticators:
- [ethereum_authenticator](contracts/starknet/authenticator/ethereum.cairo) which will authenticate a user based on a message signed by Ethereum private keys.
- [starknet_authenticator](contracts/starknet/authenticator/starknet.cairo), which will authenticate a user based on a message signed by Starknet keys.

This modularity allows spaces to authenticate users using other authentication methods: if you wanted to use Solana keys to authenticate users, you would simply need to write the authenticator contract on Starknet, and you would be able to authenticate Solana users!

#### Execution Contract

The execution contract is the contract that gets called when voting for a proposal is done. The interface can be found [here](contracts/starknet/execution/interface.cairo). The execution contract receives:
- `has_passed`: whether the proposal has passed or not (majority of `FOR`).
- `execution_hash`: hash of the transactions to be executed.
- `execution_params_len`: the length of `execution_params`, in `felt`s.
- `execution_params`: additional parameters that might be needed to properly execute these transactions.

This repo provides the [Zodiac Relayer](contracts/starknet/execution/zodiac_relayer.cairo`), which will forward the execution to the l1 Zodiac module address specified in `executions_params[0]`. To better understand this flow, you can look at the [corresponding test](test/crosschain/zodiac.ts).

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

- Ethereum tests in `tests/ethereum`: they are tests for our solidity contracts
- Starknet tests in `tests/starknet`: they are tests for our cairo contracts
- Crosschain tests in `tests/crosschain`: they are tests that will do a full flow of interaction between cairo <-> solidity code

To run those tests, you need to install and run `starknet-devent`, and run `

#### Install and run StarkNet Devnet (In a separate terminal):
```bash
pip install starknet-devnet
starknet-devnet -p 8000
```

#### Run an ethereum hardhat node (In a separate terminal)

```bash
npx hardhat node
```

#### Run tests:
```bash
yarn test
# You can also use `yarn test:l1` to test our solidity contracts,
# `yarn test:l2` to test ou cairo contracts,
# and `yarn test:l1l2` to test ou crosschain flow
```

## DISCLAIMER: STILL IN DEVELOPMENT

This project is still under heavy development. Feel free to contact us on [Discord](https://discord.snapshot.org)!

## License

Snapshot is open-sourced software licensed under the © [MIT license](LICENSE).