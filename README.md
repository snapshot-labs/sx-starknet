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

### Motivation

Governance mechanisms obey a trillemma between **decentralization**, **cost**, and **flexibility**. On the one end you have systems like Snapshot that provide a very cheap experience [1] will losts of flexibility. However it relies on one trusting the Snapshot off-chain protocol to deliver the verdict of a particular governance proposal and to not censor votes. Flexibility comes from the wide range of voting strategies than one can employ to calculate the voting power for each user. 

On the other end you have governance systems that run fully on-chain on Ethereum mainnet. Compound Governor is one example of such a sytem. All the voting logic is computed on-chain which provides an equivalent degree of decentralization to Ethereum itself. The compromise of such a system is a high cost of participation due to the high gas costs incurred when transacting on the blockchain. The flexibility of the system is also limited by cost as sophisticated voting strategies require increased on-chain logic and therfore will cost even more to utilize them.

Snapshot X aims to bridge this divide by providing a fully on-chain governance system that is 50-100x cheaper than current solutions that run on Ethereum mainnet. We hope that this will unlock massive increases in governance participation without having to make any comprimises on decentralization. This is achieved by running the voting logic on StarkNet, which provides cheap computation whilst inheriting all of the security guarrantees of Ethereum itself. Once voting on a proposal has ended, a L1-L2 message bridge is utilized to allow transactions inside the proposal to be permissionlessly executed on Ethereum mainnet. 

<p align="center">
<img src="./docs/milestones/comparisons.png" width="800">
</p>


### Architecture 

Snapshot X is designed to be as modular as possible to provide maximum configurability. As displayed in the diagram below, certain contracts have new instances which are deployed for each DAO (or more specifically per space) that utilizes Snapshot X. Whilst others are treated more like library contracts and have a single instance which is shared between all DAOs.

![](./docs/milestones/architecture.png)

#### Space contract

The [space](contracts/starknet/space/space.cairo) is THE core contract: it's in charge of tracking proposals, votes, and other general settings.
To deploy a new space, you will need to provide:
- `voting_delay`: The delay between when a proposal is created, and when the voting starts. A `voting_delay` of 0 means that as soon as the proposal is created, anyone can vote. A `voting_delay` of 3600 means that voting will start `3600` seconds after the proposal is created.
- `voting_duration`: The duration of the voting period, i.e. how long people will be able to vote for a proposal.
- `proposal_threshold`: The minimum amount of voting power needed to be able to create a new proposal in the space. Used to avoid having anyone be able to create a proposal.
- `voting_strategies`: A list of voting strategy contracts addresses that define the voting strategies used by the space. The voting power of each user will be calculated as the sum of voting powers returned for each strategy in the list for that user. More information in the [Voting Strategy](#Voting-Strategies) section.
- `authenticators`: A list of accepted authenticators. These are the ways in which a user can authenticate themselves in order to vote or propose. For more information, refer to the [Authenticators](#Authenticators) section.

Once a space has been created, users can create new proposals by calling the `propose` method (provided the caller has at least `proposal_threshold` voting power). Users don't directly interact with the `space` contract, but use one of the `authenticator` as a proxy. Once a proposal has been created, and the `voting_delay` has elapsed, users can then vote for the proposal (once again, using an `authenticator` as a proxy). Once the `voting_duration` has passed, votes are closed, and anyone can call `finalize_proposal` (this time directly on the space contract as no authentication is required): this will finalize the proposal, count the votes for/against/abstain, and call the execution contract. More information about execution in the [Execution Contract](#Execution-Contract) section.

Note that each DAO will have at least one space, however a DAO might choose to have multiple spaces if they want to create different 'categories' of proposal each with different settings.

#### Voting Strategies

Voting strategy contracts are the contracts used to determine the voting power of a user. Voting strategies can be created permissionlessly however to use one, one must whitelist the strategy contract in the relevant space contract for the DAO. The most common example is using the erc20 token balance of a user to determine his voting power. But we could imagine other voting strategies: owning a specific NFT, owning NFT of collection X and another NFT of collection Y, having participated in protocol xyz... the possibilities are endless! We provide the [single_slot_proof strategy](contracts/starknet/strategies/single_slot_proof.cairo) which allows classic ERC20 and ERC721 balances on L1 (thanks to [Fossil](#Fossil-Storage-Verifier)) to be used as voting power, but feel free to create your own strategies! We hope that the flexibility of the system will unlock a new era of programmable on-chain governance. The interface of a strategy can be found [here](contracts/starknet/strategies/interface.cairo). 

#### Fossil Storage Verifier

The backbone of the voting strategies is the Fossil module built by the awesome Oiler team. This module allows any part of the Ethereum mainnet state to be trustlessly verfied on StarkNet. Verification of Ethereum state information is achieved by submitting a proof of the state to StarkNet and then verifying that proof. Once this state information has been proved, we can then calculate voting power as an arbitrary function of the information. For more information on Fossil, refer to their [Github](https://github.com/OilerNetwork/fossil)


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


[1] Despite being off-chain, there are some costs associated with running the infrastructure. These costs are sufficiently low that it is possible for them to be fully subsidized by Snapshot Labs, providing a zero cost user experience.

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
 
