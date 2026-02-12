import { useParams } from "react-router-dom";
import { useReadContract } from "wagmi";
import { protocolAbi, erc20Abi } from "@/contracts";

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

  const { data: stableName } = useReadContract({
    address: stableToken as `0x${string}`,
    abi: erc20Abi,
    functionName: "name",
  });

  const { data: stableSymbol } = useReadContract({
    address: stableToken as `0x${string}`,
    abi: erc20Abi,
    functionName: "symbol",
  });

  const { data: collateralName } = useReadContract({
    address: collateralToken as `0x${string}`,
    abi: erc20Abi,
    functionName: "name",
  });

  const { data: collateralSymbol } = useReadContract({
    address: collateralToken as `0x${string}`,
    abi: erc20Abi,
    functionName: "symbol",
  });

  const stableNameStr = stableName ? String(stableName) : "...";
  const stableSymbolStr = stableSymbol ? String(stableSymbol) : "...";
  const collateralNameStr = collateralName ? String(collateralName) : "...";
  const collateralSymbolStr = collateralSymbol ? String(collateralSymbol) : "...";

  const collateralPercent =
    collateralRatio ? Number(collateralRatio as bigint) / 100 : 0;

  return (
    <div className="min-h-screen flex items-center justify-center px-6">

      <div className="w-full max-w-2xl bg-white/5 backdrop-blur-xl 
                      border border-white/10 rounded-2xl 
                      shadow-xl p-8 space-y-6">

        <h2 className="text-2xl font-semibold text-white">
          Market Detail
        </h2>

        {/* Protocol Address */}
        <div>
          <p className="text-gray-400 text-sm">Protocol Address</p>
          <p className="text-xs text-gray-500 break-all">
            {address}
          </p>
        </div>

        {/* Stable Token */}
        <div>
          <p className="text-gray-400 text-sm">Stable Token</p>
          <p className="text-white font-medium">
            {stableNameStr} ({stableSymbolStr})
          </p>
          <p className="text-xs text-gray-500 break-all">
            {stableToken ? String(stableToken) : "..."}
          </p>
        </div>

        {/* Collateral Token */}
        <div>
          <p className="text-gray-400 text-sm">Collateral Token</p>
          <p className="text-white font-medium">
            {collateralNameStr} ({collateralSymbolStr})
          </p>
          <p className="text-xs text-gray-500 break-all">
            {collateralToken ? String(collateralToken) : "..."}
          </p>
        </div>

        {/* Collateral Ratio */}
        <div>
          <p className="text-gray-400 text-sm">Collateral Ratio</p>
          <p className="text-white font-medium text-lg">
            {collateralPercent}%
          </p>
        </div>

      </div>
    </div>
  );
}
