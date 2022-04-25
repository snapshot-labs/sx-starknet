import { Link, useParams } from "react-router-dom"

const Space: React.FC = () => {
  const { spaceAddress } = useParams()
  return (
    <div>
      <Link to="/">Back home</Link>
      <p>welcome to space {spaceAddress}</p>
    </div>
  )
}

export default Space
