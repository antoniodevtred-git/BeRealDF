import { Routes, Route } from "react-router-dom"
import Markets from "./pages/Markets"
import MarketDetail from "./pages/MarketDetail"
import Header from "./components/Header"


export default function App() {
  return (
    <>
      <Header />
      <Routes>
        <Route path="/" element={<Markets />} />
        <Route path="/market/:address" element={<MarketDetail />} />
      </Routes>
    </>
  )
}
