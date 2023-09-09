# Snapshot X

A Cairo implementation of the Snapshot X Protocol. Refer to the [documentation](https://docs.snapshotx.xyz) for more
information.

## Architecture

The repository is split into two different parts:
1. The Starknet part under `./starknet`
2. The Ethereum part under `./ethereum`

This project uses [yarn](https://yarnpkg.com/) at the root level, [scarb](https://github.com/software-mansion/scarb) for it's [starknet](https://github.com/foundry-rs/foundry) folder and `foundry` for its `ethereum` folder.

To get started, please run `yarn`.

### Starknet

We use the [scarb](https://github.com/software-mansion/scarb) package manager for the `starknet` folder.
The source files are all under `starknet/src`. The tests are located in two different folders:
1. `starknet/src/tests/` for purely cairo tests (you might also find additional unit tests directly in other files, declared as `mod tests`)
2. `starknet/test`/ 

#### To run the `starknet/src/tests` tests

For the following commands, make sure you `cd starknet`.

To build, simply run
```sh
scarb build
```

To test, run:
```sh
scarb test
```

#### To run the `starknet/test` tests

// First, you will need to install [starknet-devnet](https://github.com/0xSpaceShard/starknet-devnet) ?
TODO

### Ethereum

We use the [foundry](https://github.com/foundry-rs/foundry) toolkit for the `ethereum` folder.
The source files are all under `ethereum/src`. `ethereum/src/mocks` contain mock implementations useful for testing.

The tests are located in `ethereum/test`.

#### To runt the `ethereum/test` tests

TODO