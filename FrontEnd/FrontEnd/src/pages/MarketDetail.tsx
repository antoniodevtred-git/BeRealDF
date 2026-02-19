import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseUnits } from "viem";
import { useState } from "react";
import { useParams } from "react-router-dom";
import { useReadContract } from "wagmi";
import { protocolAbi, erc20Abi } from "@/contracts";
import MarketStatsCard from "@/components/MarketStatsCard";
import BorrowCard from "@/components/BorrowCard";


export default function MarketDetail() {
    const { address } = useParams();

    const { address: user } = useAccount();
    const [amount, setAmount] = useState("");

    const { data: lenderBalance } = useReadContract({
        address: address as `0x${string}`,
        abi: protocolAbi,
        functionName: "getLenderBalance",
        args: user ? [user] : undefined,
    });

    const { writeContract, data: hash } = useWriteContract();

    const { isLoading: isConfirming } = useWaitForTransactionReceipt({
        hash,
    });

    const handleDeposit = () => {
        if (!amount) return;

        writeContract({
            address: address as `0x${string}`,
            abi: protocolAbi,
            functionName: "deposit",
            args: [parseUnits(amount, 18)],
        });
    };

    const handleWithdraw = () => {
        if (!amount) return;

        writeContract({
            address: address as `0x${string}`,
            abi: protocolAbi,
            functionName: "withdraw",
            args: [parseUnits(amount, 18)],
        });
    };

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
            <div className="flex gap-8">

                {/* LEFT COLUMN — Market Detail */}
                <div
                    className="w-full max-w-2xl bg-white/5 backdrop-blur-xl
                  border border-white/10 rounded-2xl
                  shadow-xl p-8 space-y-6"
                >
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

                {/* RIGHT COLUMN */}
                <div className="flex flex-col gap-6 w-80">

                    {/* Market Stats Card */}
                    <MarketStatsCard
                        protocolAddress={address as `0x${string}`}
                    />

                    {/* Supply Card */}
                    <div className="bg-white/5 border border-white/10 rounded-2xl p-6 backdrop-blur">
                        <h2 className="text-lg font-semibold mb-4 text-white">
                            Supply Stablecoins
                        </h2>

                        {!user ? (
                            <p className="text-gray-400">
                                Connect your wallet to supply liquidity.
                            </p>
                        ) : (
                            <div className="space-y-4">

                                <div>
                                    <p className="text-sm text-gray-400">
                                        Your supplied balance
                                    </p>
                                    <p className="text-white font-medium">
                                        {lenderBalance
                                            ? Number(lenderBalance) / 1e18
                                            : 0}
                                    </p>
                                </div>

                                <input
                                    type="number"
                                    placeholder="Amount"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="w-full px-4 py-2 rounded-lg bg-black/40 border border-white/10 text-white"
                                />

                                <div className="flex gap-3">
                                    <button
                                        onClick={handleDeposit}
                                        className="flex-1 bg-primary hover:opacity-90 transition rounded-lg py-2 text-white"
                                    >
                                        Deposit
                                    </button>

                                    <button
                                        onClick={handleWithdraw}
                                        className="flex-1 bg-red-500 hover:opacity-90 transition rounded-lg py-2 text-white"
                                    >
                                        Withdraw
                                    </button>
                                </div>

                                {isConfirming && (
                                    <p className="text-yellow-400 text-sm">
                                        Transaction confirming...
                                    </p>
                                )}
                            </div>
                        )}
                    </div>
                    <BorrowCard protocolAddress={address as `0x${string}`} />
                </div>

            </div>
        </div>
    );

}
