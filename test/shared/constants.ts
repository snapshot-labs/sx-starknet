import { hash } from 'starknet';
const { getSelectorFromName } = hash;

export const PROPOSE_SELECTOR = getSelectorFromName('propose');
export const VOTE_SELECTOR = getSelectorFromName('vote');
export const AUTHENTICATE_SELECTOR = getSelectorFromName('authenticate');
