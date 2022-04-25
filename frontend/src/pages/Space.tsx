import { useEffect } from "react"
import { useDispatch, useSelector } from "react-redux"
import { Link, useParams } from "react-router-dom"
import { getSpace } from "../service/state-updater"
import { Account, Proposal, Space, State } from "../types"

const Proposals: React.FC<{ spaceAddress: string; proposals: Proposal[] }> = ({
  spaceAddress,
  proposals,
}) => {
  return (
    <div>
      {proposals.map((proposal) => {
        return (
          <div key={proposal.id} className="proposalLink">
            <Link to={`/space/${spaceAddress}/${proposal.id}`}></Link>
          </div>
        )
      })}
    </div>
  )
}

const Whitelist: React.FC<{ whitelist: Account[] }> = ({ whitelist }) => {
  return (
    <div className="whitelist">
      {whitelist.map((account) => {
        return <div className="whitelistElement" key={account.address}>{account.address}</div>
      })}
    </div>
  )
}

const SpaceContainer: React.FC<{ space: Space | undefined }> = ({ space }) => {
  if (space === undefined) return <div>loading</div>

  return (
    <div className="space">
      <p>this is the space address {space.address}</p>
      <h1>Whitelist</h1>
      <Whitelist whitelist={space.whitelist} />
      <Proposals proposals={space.proposals} spaceAddress={space.address} />
    </div>
  )
}

const SpacePage: React.FC = () => {
  const { spaceAddress } = useParams() as { spaceAddress: string }
  const { spaceMap } = useSelector<State, State>((state) => state)
  const dispatch = useDispatch()

  const space = spaceMap[spaceAddress]
  useEffect(() => {
    if (space === undefined) {
      getSpace(dispatch, spaceAddress)
    }
  }, [spaceAddress])

  return (
    <div>
      <Link to="/">Back home</Link>
      <p>welcome to space {spaceAddress}</p>
      <SpaceContainer space={space} />
    </div>
  )
}

export default SpacePage
