import { createSlice } from "@reduxjs/toolkit"
import { State } from "./types"

const initialState: State = {spaceMap:{}}

const slice = createSlice({
  initialState,
  name: "safe-x",
  reducers: {
    newSpace(state, action) {
      state.spaceMap[action.payload.address] = action.payload
    },
    newProposal(state, action) {
      const {spaceAddress, proposal} = action.payload
      state.spaceMap[spaceAddress].proposals[proposal.id] = proposal
    }
  }
})

export default slice