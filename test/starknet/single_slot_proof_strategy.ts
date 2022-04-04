// REMOVING TEMPORARILY AS WE WAIT FOR AN UPDATE TO FOSSIL

import { StarknetContract, Account } from 'hardhat/types/runtime';
import { expect } from 'chai';
import { starknet } from 'hardhat';
import { block } from './data/blocks';
import { proofs } from './data/proofs';
import { SplitUint256, IntsSequence } from './shared/types';
import { hexToBytes } from './shared/helpers';
import { ProcessBlockInputs, ProofInputs } from './shared/parseRPCData';
import { encodeParams } from './shared/singleSlotProofStrategyEncoding';

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
  const l1RelayerAccount = await starknet.deployAccount('OpenZeppelin');
  await account.invoke(factsRegistry, 'initialize', {
    l1_headers_store_addr: BigInt(l1HeadersStore.address),
  });
  await account.invoke(l1HeadersStore, 'initialize', {
    l1_messages_origin: BigInt(l1RelayerAccount.starknetContract.address),
  });
  return new Fossil(factsRegistry, l1HeadersStore, l1RelayerAccount);
}

async function setup() {
  const account = await starknet.deployAccount('OpenZeppelin');
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
  // Encode block header and then submit to L1 Headers Store
  const processBlockInputs = ProcessBlockInputs.fromBlockRPCData(block);
  await fossil.l1RelayerAccount.invoke(fossil.l1HeadersStore, 'process_block', {
    options_set: processBlockInputs.blockOptions,
    block_number: processBlockInputs.blockNumber,
    block_header_rlp_bytes_len: processBlockInputs.headerInts.bytesLength,
    block_header_rlp: processBlockInputs.headerInts.values,
  });
  return {
    account: account as Account,
    singleSlotProofStrategy: singleSlotProofStrategy as StarknetContract,
    fossil: fossil as Fossil,
  };
}

describe('Snapshot X Single Slot Strategy:', () => {
  it('The strategy should return the voting power', async () => {
    // Encode proof data to produce the inputs for the account and storage proofs.
    const proofInputs = ProofInputs.fromProofRPCData(block.number, proofs, encodeParams);

    // Deploy Fossil storage verifier instance and the voting strategy contract.
    const { account, singleSlotProofStrategy, fossil } = await setup();

    // Verify an account proof to obtain the storage root for the account at the specified block number trustlessly on-chain.
    account.invoke(fossil.factsRegistry, 'prove_account', {
      options_set: proofInputs.accountOptions,
      block_number: proofInputs.blockNumber,
      account: {
        word_1: proofInputs.ethAddress.values[0],
        word_2: proofInputs.ethAddress.values[1],
        word_3: proofInputs.ethAddress.values[2],
      },
      proof_sizes_bytes: proofInputs.accountProofSizesBytes,
      proof_sizes_words: proofInputs.accountProofSizesWords,
      proofs_concat: proofInputs.accountProof,
    });

    // Check the storage root is stored. (This returns zero which shows that the prove_account tx has not been included yet)
    const { res: out } = await fossil.factsRegistry.call('get_verified_account_storage_hash', {
      account_160: proofInputs.ethAddressFelt,
      block: proofInputs.blockNumber,
    });
    console.log(out);

    // Second time it returns the hash showing that the prove_account tx has been included
    const { res: out2 } = await fossil.factsRegistry.call('get_verified_account_storage_hash', {
      account_160: proofInputs.ethAddressFelt,
      block: proofInputs.blockNumber,
    });
    console.log(out2);

    // Second time it returns the hash showing that the prove_account tx has been included
    const { res: out3 } = await fossil.factsRegistry.call('get_verified_account_storage_hash', {
      account_160: proofInputs.ethAddressFelt,
      block: proofInputs.blockNumber,
    });
    console.log(out3);

    // Obtain voting power for the account by verifying the storage proof.
    const { voting_power: vp } = await singleSlotProofStrategy.call('get_voting_power', {
      block: proofInputs.blockNumber,
      account_160: proofInputs.ethAddressFelt,
      params: proofInputs.votingPowerParams,
    });

    // Assert voting power obtained from strategy is correct
    expect(new SplitUint256(vp.low, vp.high)).to.deep.equal(
      SplitUint256.fromUint(BigInt(proofs.storageProof[0].value))
    );
  }).timeout(1000000);
});
