import { useParams } from "react-router-dom"

export default function MarketDetail() {
  const { address } = useParams()

  return (
    <div className="max-w-4xl mx-auto p-6 text-white">
      <h2 className="text-2xl font-semibold mb-4">
        Market Detail
      </h2>

      <div className="bg-white/5 p-6 rounded-xl space-y-3">
        <p><strong>Protocol Address:</strong> {address}</p>
        <p>Stable Token: ...</p>
        <p>Collateral Token: ...</p>
        <p>Collateral Ratio: ...</p>
      </div>
    </div>
  )
}
