import { Link } from "react-router-dom"

const Home: React.FC = () => {
  return (
    <div>
      <h1>Welcome to safe-x</h1>
      <Link to={"space-factory"}>Create a space</Link>
    </div>
  )
}

export default Home
