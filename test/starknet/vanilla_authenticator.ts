import { StarknetContract } from 'hardhat/types/runtime';
import { starknet } from 'hardhat';
import { stark } from 'starknet';
const { getSelectorFromName } = stark;

const EXECUTE_METHOD = 'execute';
const PROPOSAL_METHOD = 'propose';
const VOTE_METHOD = 'vote';
const SPACE_CONTRACT = BigInt(1337);

async function setup() {
  const vanillaAuthenticatorFactory = await starknet.getContractFactory(
    './contracts/starknet/authenticator/vanilla.cairo'
  );
  const vanillaAuthenticator = await vanillaAuthenticatorFactory.deploy();
  return {
    vanillaAuthenticator: vanillaAuthenticator as StarknetContract,
  };
}

describe('Authenticator execute call:', () => {
  it('Calls the vote method correctly', async () => {
    const { vanillaAuthenticator } = await setup();

    // TODO: Uncomment these when merging vanilla_space
    // await vanillaAuthenticator.call(EXECUTE_METHOD, {
    //   to: SPACE_CONTRACT,
    //   function_selector: BigInt(getSelectorFromName(VOTE_METHOD)),
    //   calldata: [],
    // });
  }).timeout(60000);

  it('Calls the proposal method correctly', async () => {
    const { vanillaAuthenticator } = await setup();

    // TODO: Uncomment these when merging vanilla_space
    // await vanillaAuthenticator.call(EXECUTE_METHOD, {
    //   to: SPACE_CONTRACT,
    //   function_selector: BigInt(getSelectorFromName(PROPOSAL_METHOD)),
    //   calldata: [],
    // });
  }).timeout(60000);
});
