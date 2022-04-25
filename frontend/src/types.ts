// todo change to felt
type Address = BigInt

type Account = {
  address: Address
}

type Proposal = {
  id: number,
  signers: Account[]
}

type Space = {
  address: string,
  whitelist: Account[],
  proposals: Proposal[]
}

export type State = {
  spaceMap: {[address: string]: Space}
}