import "./App.css"
import WhitelistFactory from "./pages/WhitelistFactory"
import { BrowserRouter, Route, Routes } from "react-router-dom"
import Home from "./pages/Home"
import SpaceFactory from "./pages/SpaceFactory"
import Space from "./pages/Space"
import Proposal from "./pages/Proposal"

function App() {
  return (
    <div className="App">
      <BrowserRouter>
        <Routes>
          <Route path="/whitelist-factory" element={<WhitelistFactory />} />
          <Route path="/space-factory" element={<SpaceFactory />} />
          <Route path="/space/:spaceAddress" element={<Space />} />
          <Route path="/space/:spaceAddress/:proposalId" element={<Proposal />} />
          <Route path="/" element={<Home />} />
        </Routes>
      </BrowserRouter>
    </div>
  )
}

export default App
