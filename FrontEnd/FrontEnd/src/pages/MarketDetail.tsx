import { useParams } from "react-router-dom";
import { useReadContract } from "wagmi";
import { protocolAbi } from "@/contracts";

export default function MarketDetail() {
  const { address } = useParams();

  const { data: stableToken } = useReadContract({
    address: address as `0x${string}`,
    abi: protocolAbi,
    functionName: "stableToken",
  });

  const { data: collateralToken } = useReadContract({
    address: address as `0x${string}`,
    abi: protocolAbi,
    functionName: "collateralToken",
  });

  const { data: collateralRatio } = useReadContract({
    address: address as `0x${string}`,
    abi: protocolAbi,
    functionName: "collateralRatio",
  });

  return (
    <div className="max-w-4xl mx-auto p-6 text-white">
      <h1 className="text-2xl mb-6">Market Detail</h1>

      <div className="space-y-3 text-sm">
        <p><strong>Protocol Address:</strong> {address}</p>
        <p><strong>Stable Token:</strong> {stableToken as string}</p>
        <p><strong>Collateral Token:</strong> {collateralToken as string}</p>
        <p><strong>Collateral Ratio:</strong> {collateralRatio?.toString()}</p>
      </div>
    </div>
  );
}
