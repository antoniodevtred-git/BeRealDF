import Header from "./components/Header"
import LenderCard from "./components/LenderCard"

export default function App() {
  return (
    <div className="min-h-screen bg-background text-white">
      {/* Header */}
      <Header />

      {/* Main content */}
      <main className="flex justify-center px-6 py-16">
        <LenderCard />
      </main>
    </div>
  )
}
