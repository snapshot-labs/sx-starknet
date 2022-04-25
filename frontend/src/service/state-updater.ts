import { AnyAction } from "@reduxjs/toolkit"
import { Dispatch } from "react"
import slice from "../slice"
import { fetchProposal, fetchSpace } from "./fetcher"

export const getProposal = async (
  dispatch: Dispatch<AnyAction>,
  spaceAddress: string,
  proposalId: number
): Promise<void> => {
  const proposal = await fetchProposal(spaceAddress, proposalId)
  dispatch(slice.actions.newProposal({ spaceAddress, proposal }))
}

export const getSpace = async (
  dispatch: Dispatch<AnyAction>,
  spaceAddress: string
): Promise<void> => {
  const space = await fetchSpace(spaceAddress)
  dispatch(slice.actions.newSpace(space))
}
