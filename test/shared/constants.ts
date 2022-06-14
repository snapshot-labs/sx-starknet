import { hash } from 'starknet';
const { getSelectorFromName } = hash;

export const PROPOSE_SELECTOR = BigInt(getSelectorFromName('propose'));
export const VOTE_SELECTOR = BigInt(getSelectorFromName('vote'));
