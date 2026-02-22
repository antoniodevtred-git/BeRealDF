import { useReadContract } from "wagmi";
import { FACTORY_ADDRESS, marketFactoryAbi } from "@/contracts";

export function MarketsList() {
  const { data: markets, isLoading } = useReadContract({
    address: FACTORY_ADDRESS,
    abi: marketFactoryAbi,
    functionName: "getAllMarkets",
  });

  if (isLoading) {
    return <p className="text-gray-400">Loading markets...</p>;
  }

  if (!markets || markets.length === 0) {
    return <p className="text-gray-400">No markets created yet</p>;
  }

  return (
    <div className="grid gap-4">
      {markets.map((market, index) => (
        <div
          key={index}
          className="rounded-xl border border-white/10 p-4 bg-white/5"
        >
          <p className="text-sm text-gray-400">Lending Market:</p>
          <p className="font-mono text-sm">{market.protocol}</p>

          <p className="mt-2 text-sm text-gray-400">Borrow Token: </p>
          <p className="font-mono text-sm">{market.stableToken}</p>
          

          <p className="mt-2 text-sm text-gray-400">Collateral Token: </p>
          <p className="font-mono text-sm">{market.collateralToken}</p>

          <p className="mt-2 text-sm text-gray-400">
            Collateral ratio:
          </p>
          <p>{Number(market.collateralRatio) / 100}%</p>
        </div>
      ))}
    </div>
  );
}
