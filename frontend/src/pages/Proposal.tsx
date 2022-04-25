import { useEffect } from "react"
import { useDispatch, useSelector } from "react-redux"
import { Link, useParams } from "react-router-dom"
import { getProposal, getSpace } from "../service/state-updater"
import { Proposal, State } from "../types"

const ProposalContainer: React.FC<{ proposal: Proposal | undefined }> = ({
  proposal,
}) => {
  if (proposal === undefined) return null
  return (
    <div>
      <h1>Proposal #{proposal.id}</h1>
      <ul>
        {proposal.signers.map((signer) => {
          return <li key={signer.address}>{signer.address}</li>
        })}
      </ul>
    </div>
  )
}

const ProposalPage: React.FC = () => {
  const { spaceAddress, proposalId } = useParams() as {
    spaceAddress: string
    proposalId: string
  }
  const dispatch = useDispatch()
  const { spaceMap } = useSelector<State, State>((state) => state)
  const space = spaceMap[spaceAddress]
  const proposal = space ? space.proposals[Number(proposalId)] : undefined

  useEffect(() => {
    if (space === undefined) {
      getSpace(dispatch, spaceAddress)
    } else if (proposal === undefined) {
      getProposal(dispatch, spaceAddress, Number(proposalId))
    }
  }, [spaceAddress, proposalId, space])

  return (
    <div>
      <Link to="/">Back home</Link>
      <p>
        welcome to proposal {proposalId} in space {spaceAddress}
      </p>
      <ProposalContainer proposal={proposal} />
    </div>
  )
}

export default ProposalPage
