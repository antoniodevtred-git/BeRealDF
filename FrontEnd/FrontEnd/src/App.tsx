import Header from "@/components/Header";
import { MarketsList } from "@/components/MarketsList";

export default function App() {
  return (
    <div className="min-h-screen bg-background text-white">
      <Header />

      <main className="max-w-7xl mx-auto px-6 py-10">
        <h2 className="text-2xl font-semibold mb-6">Markets</h2>
        <MarketsList />
      </main>
    </div>
  );
}
