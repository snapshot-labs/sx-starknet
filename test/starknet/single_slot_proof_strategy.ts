import { StarknetContract, Account } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import Common, { Chain, Hardfork } from '@ethereumjs/common';
import { bufferToHex } from 'ethereumjs-util';
import blockFromRpc from '@ethereumjs/block/dist/from-rpc';
import { block } from './data/blocks';
import { proofs } from './data/proofs';
import { SplitUint256, IntsSequence } from './shared/types';
import { hexToBytes } from './shared/helpers';
import { encodeParams } from './shared/single_slot_proof_strategy_encoding';

class Fossil {
  factsRegistry: StarknetContract;
  l1HeadersStore: StarknetContract;
  l1RelayerAccount: Account;

  constructor(
    factsRegistry: StarknetContract,
    l1HeadersStore: StarknetContract,
    l1RelayerAccount: Account
  ) {
    this.factsRegistry = factsRegistry;
    this.l1HeadersStore = l1HeadersStore;
    this.l1RelayerAccount = l1RelayerAccount;
  }
}

async function setupFossil(account: Account) {
  const factsRegistryFactory = await starknet.getContractFactory(
    'fossil/contracts/starknet/FactsRegistry.cairo'
  );
  const l1HeadersStoreFactory = await starknet.getContractFactory(
    'fossil/contracts/starknet/L1HeadersStore.cairo'
  );
  const factsRegistry = await factsRegistryFactory.deploy();
  const l1HeadersStore = await l1HeadersStoreFactory.deploy();
  const l1RelayerAccount = await starknet.deployAccountFromABI(
    'account/Account.cairo',
    'OpenZeppelin'
  );
  await account.invoke(factsRegistry, 'initialize', {
    l1_headers_store_addr: BigInt(l1HeadersStore.address),
  });
  await account.invoke(l1HeadersStore, 'initialize', {
    l1_messages_origin: BigInt(l1RelayerAccount.starknetContract.address),
  });
  return new Fossil(factsRegistry, l1HeadersStore, l1RelayerAccount);
}

async function setup() {
  const account = await starknet.deployAccountFromABI('account/Account.cairo', 'OpenZeppelin');
  const fossil = await setupFossil(account);
  const singleSlotProofStrategyFactory = await starknet.getContractFactory(
    'contracts/starknet/strategies/single_slot_proof.cairo'
  );
  const singleSlotProofStrategy = await singleSlotProofStrategyFactory.deploy({
    fact_registry: BigInt(fossil.factsRegistry.address),
  });
  // Submit blockhash to L1 Headers Store (via dummy function rather than L1 -> L2 bridge)
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'receive_from_l1', {
    parent_hash: IntsSequence.fromBytes(hexToBytes(block.hash)).values,
    block_number: block.number + 1,
  });
  // Rlp encode block header and then submit to L1 Headers Store
  const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });
  const header = blockFromRpc(block, [], { common }).header;
  const headerRlp = bufferToHex(header.serialize());
  const headerInts = IntsSequence.fromBytes(hexToBytes(headerRlp));
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'process_block', {
    options_set: 8,
    block_number: block.number,
    block_header_rlp_bytes_len: headerInts.bytesLength,
    block_header_rlp: headerInts.values,
  });
  return {
    account: account as Account,
    singleSlotProofStrategy: singleSlotProofStrategy as StarknetContract,
    fossil: fossil as Fossil,
  };
}

function getProofInputs() {
  const account_proof = proofs.accountProof.map((node) => IntsSequence.fromBytes(hexToBytes(node)));
  let flat_account_proof: bigint[] = [];
  let flat_account_proof_sizes_bytes: bigint[] = [];
  let flat_account_proof_sizes_words: bigint[] = [];
  for (const node of account_proof) {
    flat_account_proof = flat_account_proof.concat(node.values);
    flat_account_proof_sizes_bytes = flat_account_proof_sizes_bytes.concat([
      BigInt(node.bytesLength),
    ]);
    flat_account_proof_sizes_words = flat_account_proof_sizes_words.concat([
      BigInt(node.values.length),
    ]);
  }
  const ethAddress = IntsSequence.fromBytes(hexToBytes(proofs.address));
  const slot = IntsSequence.fromBytes(hexToBytes(proofs.storageProof[0].key));
  const storage_proof = proofs.storageProof[0].proof.map((node) =>
    IntsSequence.fromBytes(hexToBytes(node))
  );
  let flat_storage_proof: bigint[] = [];
  let flat_storage_proof_sizes_bytes: bigint[] = [];
  let flat_storage_proof_sizes_words: bigint[] = [];
  for (const node of storage_proof) {
    flat_storage_proof = flat_storage_proof.concat(node.values);
    flat_storage_proof_sizes_bytes = flat_storage_proof_sizes_bytes.concat([
      BigInt(node.bytesLength),
    ]);
    flat_storage_proof_sizes_words = flat_storage_proof_sizes_words.concat([
      BigInt(node.values.length),
    ]);
  }
  const votingPowerParams = encodeParams(
    slot.values,
    flat_storage_proof_sizes_bytes,
    flat_storage_proof_sizes_words,
    flat_storage_proof
  );
  return {
    ethAddress,
    flat_account_proof_sizes_bytes,
    flat_account_proof_sizes_words,
    flat_account_proof,
    votingPowerParams,
  };
}

describe('Snapshot X Single Slot Strategy:', () => {
  it('The strategy should return the voting power', async () => {
    // Deploy Fossil storage verifier instance and the voting strategy contract.
    const { account, singleSlotProofStrategy, fossil } = await setup();

    // Encode proof data to produce the inputs for the account and storage proofs.
    const {
      ethAddress,
      flat_account_proof_sizes_bytes,
      flat_account_proof_sizes_words,
      flat_account_proof,
      votingPowerParams,
    } = getProofInputs();

    // Verify an account proof to obtain the storage root for the account at the specified block number trustlessly on-chain.
    account.invoke(fossil.factsRegistry, 'prove_account', {
      options_set: 15,
      block_number: block.number,
      account: {
        word_1: ethAddress.values[0],
        word_2: ethAddress.values[1],
        word_3: ethAddress.values[2],
      },
      proof_sizes_bytes: flat_account_proof_sizes_bytes,
      proof_sizes_words: flat_account_proof_sizes_words,
      proofs_concat: flat_account_proof,
    });

    // Check the storage root is stored. (This returns zero which shows that the prove_account tx has not been included yet)
    const { res: out } = await fossil.factsRegistry.call('get_verified_account_storage_hash', {
      account_160: BigInt(proofs.address),
      block: block.number,
    });
    console.log(out);

    // Obtain voting power for the account by verifying the storage proof.
    const { voting_power: vp } = await singleSlotProofStrategy.call('get_voting_power', {
      block: block.number,
      account_160: BigInt(proofs.address),
      params: votingPowerParams,
    });

    // Assert voting power obtained from strategy is correct
    expect(new SplitUint256(vp.low, vp.high)).to.deep.equal(
      SplitUint256.fromUint(BigInt(proofs.storageProof[0].value))
    );
  }).timeout(2400000);
});
