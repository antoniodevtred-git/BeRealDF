import { Link } from "react-router-dom"
import { useReadContract } from "wagmi"
import { FACTORY_ADDRESS, marketFactoryAbi } from "@/contracts"

type MarketInfo = {
  protocol: `0x${string}`
  stableToken: `0x${string}`
  collateralToken: `0x${string}`
  collateralRatio: bigint
}

export default function Markets() {
  const { data, isLoading, error } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: marketFactoryAbi,
    functionName: "getAllMarkets",
  })

  const markets = data as MarketInfo[] | undefined

  if (isLoading) {
    return (
      <div className="p-10 text-white text-center">
        Loading markets...
      </div>
    )
  }

  if (error) {
    return (
      <div className="p-10 text-red-400 text-center">
        Error loading markets
      </div>
    )
  }

  if (!markets || markets.length === 0) {
    return (
      <div className="p-10 text-gray-400 text-center">
        No markets created yet
      </div>
    )
  }

  return (
    <div className="max-w-6xl mx-auto p-8">
      <h2 className="text-2xl font-semibold text-white mb-8">
        Available Markets
      </h2>

      <div className="grid md:grid-cols-2 gap-6">
        {markets.map((market, index) => (
          <Link
            key={index}
            to={`/market/${market.protocol}`}
            className="bg-white/5 backdrop-blur p-6 rounded-xl hover:bg-white/10 transition border border-white/10"
          >
            <div className="space-y-2 text-white">
              <p className="text-sm text-gray-400">Protocol</p>
              <p className="font-mono text-sm break-all">
                {market.protocol}
              </p>

              <p className="text-sm text-gray-400 mt-4">
                Collateral Ratio
              </p>
              <p className="text-lg font-semibold text-secondary">
                {Number(market.collateralRatio) / 100}%
              </p>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
