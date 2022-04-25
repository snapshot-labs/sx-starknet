// change to evm address type?
type Address = string

export type Account = {
  address: Address
}

export type Proposal = {
  id: number,
  signers: Account[]
}

export type Space = {
  address: string,
  whitelist: Account[],
  proposals: Proposal[]
}

export type State = {
  spaceMap: {[address: string]: Space}
}