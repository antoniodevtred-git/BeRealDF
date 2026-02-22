import { useReadContract } from "wagmi";
import { protocolAbi } from "@/contracts";

interface Props {
  protocolAddress: `0x${string}`;
}

export default function MarketStatsCard({ protocolAddress }: Props) {
  const { data: totalSupplied } = useReadContract({
    address: protocolAddress,
    abi: protocolAbi,
    functionName: "totalSupplied",
  });

  const { data: protocolFeeBps } = useReadContract({
    address: protocolAddress,
    abi: protocolAbi,
    functionName: "protocolFeeBps",
  });

  const { data: owner } = useReadContract({
    address: protocolAddress,
    abi: protocolAbi,
    functionName: "owner",
  });

  const { data: feeRecipient } = useReadContract({
    address: protocolAddress,
    abi: protocolAbi,
    functionName: "feeRecipient",
  });

  const suppliedFormatted = totalSupplied
    ? Number(totalSupplied) / 1e18
    : 0;

  const feePercent = protocolFeeBps
    ? Number(protocolFeeBps) / 100
    : 0;

  return (
    <div className="bg-white/5 border border-white/10 rounded-2xl p-6 w-80 space-y-4">
      <h3 className="text-lg font-semibold">Market Stats</h3>

      <div>
        <p className="text-sm text-gray-400">Total Supplied</p>
        <p className="text-white">{suppliedFormatted}</p>
      </div>

      <div>
        <p className="text-sm text-gray-400">Protocol Fee</p>
        <p className="text-white">{feePercent}%</p>
      </div>

      <div>
        <p className="text-sm text-gray-400">Owner</p>
        <p className="text-xs text-gray-300 break-all">{owner as string}</p>
      </div>

      <div>
        <p className="text-sm text-gray-400">Fee Recipient</p>
        <p className="text-xs text-gray-300 break-all">
          {feeRecipient as string}
        </p>
      </div>
    </div>
  );
}
