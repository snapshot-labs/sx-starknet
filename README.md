# Snapshot X

A Cairo implementation of the Snapshot X Protocol. Refer to the [documentation](https://docs.snapshotx.xyz) for more
information.

## Architecture

The repository is split into two different parts:
1. The Cairo files are in a [Scarb](https://github.com/software-mansion/scarb) package under `./starknet`
2. The Solidity files are in a [Foundry](https://github.com/foundry-rs/foundry) package under `./ethereum`

There is also Hardhat Project in the root directory for crosschain tests. 

### Install Python and Yarn requirements: 

```bash
python3.9 -m venv ~/cairo_venv
source ~/cairo_venv/bin/activate
pip3 install -r requirements.txt
yarn
```


#### To run the Scarb tests

For the following commands, make sure you `cd starknet`.

To build, simply run
```sh
scarb build
```

To test, run:
```sh
scarb test
```

#### To run the Hardhat tests

// First, you will need to  install [starknet-devnet](https://github.com/0xSpaceShard/starknet-devnet) ?
TODO

### Ethereum

We use the [foundry](https://github.com/foundry-rs/foundry) toolkit for the `ethereum` folder.
The source files are all under `ethereum/src`. `ethereum/src/mocks` contain mock implementations useful for testing.

The tests are located in `ethereum/test`.

#### To runt the `ethereum/test` tests

TODO