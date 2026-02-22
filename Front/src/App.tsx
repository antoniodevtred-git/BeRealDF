import { Routes, Route } from "react-router-dom"
import Markets from "./pages/Markets"
import MarketDetail from "./pages/MarketDetail"
import Header from "./components/Header"
import Navbar from "./components/Navbar"


export default function App() {
  return (
    <>
      <Header />
      <Navbar />
      <Routes>
        <Route path="/" element={<Markets />} />
        <Route path="/market/:address" element={<MarketDetail />} />
      </Routes>
    </>
  )
}
