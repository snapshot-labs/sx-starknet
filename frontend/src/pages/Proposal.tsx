import { Link, useParams } from "react-router-dom"

const Proposal: React.FC = () => {
  const { spaceAddress, proposalId } = useParams()

  return (
    <div>
      <Link to="/">Back home</Link>
      <p>
        welcome to proposal {proposalId} in space {spaceAddress}
      </p>
    </div>
  )
}

export default Proposal
