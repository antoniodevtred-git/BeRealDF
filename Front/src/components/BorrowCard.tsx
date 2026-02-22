import { useState } from "react";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { parseUnits } from "viem";
import { protocolAbi } from "@/contracts";

interface Props {
    protocolAddress: `0x${string}`;
}

export default function BorrowCard({ protocolAddress }: Props) {
    const { address } = useAccount();
    const { writeContract } = useWriteContract();

    const [collateralAmount, setCollateralAmount] = useState("");
    const [borrowAmount, setBorrowAmount] = useState("");
    const [repayAmount, setRepayAmount] = useState("");

    if (!address) return null;

    // 🔹 Get full borrower struct
    const { data: borrowerData } = useReadContract({
        address: protocolAddress,
        abi: protocolAbi,
        functionName: "getBorrower",
        args: [address],
    });

    // 🔹 Get total debt with interest
    const { data: totalDebt } = useReadContract({
        address: protocolAddress,
        abi: protocolAbi,
        functionName: "calculateTotalDebt",
        args: [address],
    });

    // 🔹 Get collateral ratio
    const { data: collateralRatio } = useReadContract({
        address: protocolAddress,
        abi: protocolAbi,
        functionName: "collateralRatio",
    });

    const ratio = collateralRatio ? Number(collateralRatio) : 0;

    const collateralBalance =
        borrowerData ? (borrowerData as any).collateralDeposited : 0n;

    const debt = totalDebt ?? 0n;

    // 🔹 Max borrow allowed
    const maxBorrow =
        collateralBalance && collateralRatio
            ? (Number(collateralBalance) * Number(collateralRatio)) / 10000
            : 0;

    const borrowTooHigh =
        !!borrowAmount &&
        Number(borrowAmount) > maxBorrow / 1e18;

    const healthFactor =
        debt && Number(debt) > 0
            ? (Number(collateralBalance) * Number(collateralRatio)) /
            (Number(debt) * 10000)
            : 0;

    const simulatedDebt =
        borrowAmount && Number(borrowAmount) > 0
            ? Number(debt) + Number(parseUnits(borrowAmount || "0", 18))
            : Number(debt);

    const simulatedHealthFactor =
        simulatedDebt > 0
            ? (Number(collateralBalance) * ratio) /
            (simulatedDebt * 10000)
            : 0;

    const borrowDisabled =
        borrowTooHigh ||
        simulatedHealthFactor < 1;

    const maxDebtBeforeLiquidation =
        (Number(collateralBalance) * ratio) / 10000;

    const liquidationBuffer =
        maxDebtBeforeLiquidation - Number(debt);

    // ----------------------------
    // Actions
    // ----------------------------

    const handleDepositCollateral = () => {
        if (!collateralAmount) return;

        writeContract({
            address: protocolAddress,
            abi: protocolAbi,
            functionName: "depositCollateral",
            args: [parseUnits(collateralAmount, 18)],
        });
    };

    const handleBorrow = () => {
        if (!borrowAmount || borrowTooHigh) return;

        writeContract({
            address: protocolAddress,
            abi: protocolAbi,
            functionName: "borrow",
            args: [parseUnits(borrowAmount, 18)],
        });
    };

    const handleRepay = () => {
        if (!repayAmount) return;

        writeContract({
            address: protocolAddress,
            abi: protocolAbi,
            functionName: "repay",
            args: [parseUnits(repayAmount, 18)],
        });
    };

    // ----------------------------
    // UI
    // ----------------------------

    return (
        <div className="bg-white/5 border border-white/10 rounded-2xl p-6 backdrop-blur space-y-6 w-80">

            <h2 className="text-lg font-semibold text-white">Borrow</h2>

            {/* User Position */}
            <div className="space-y-2">
                <div>
                    <p className="text-sm text-gray-400">Your Collateral</p>
                    <p className="text-white font-medium">
                        {Number(collateralBalance) / 1e18}
                    </p>
                </div>

                <div>
                    <p className="text-sm text-gray-400">Health Factor</p>
                    <p
                        className={`font-medium ${debt && Number(debt) > 0
                            ? healthFactor > 1.5
                                ? "text-green-400"
                                : healthFactor > 1
                                    ? "text-yellow-400"
                                    : "text-red-500"
                            : "text-green-400"
                            }`}
                    >
                        {debt && Number(debt) > 0
                            ? healthFactor.toFixed(2)
                            : "∞"}
                    </p>
                </div>

                <div>
                    <p className="text-sm text-gray-400">Liquidation Buffer</p>
                    <p className="text-white font-medium">
                        {liquidationBuffer > 0
                            ? (liquidationBuffer / 1e18).toFixed(4)
                            : "0"}
                    </p>
                </div>

                <div className="h-2 w-full bg-white/10 rounded-full overflow-hidden mt-2">
                    <div
                        className={`h-full ${healthFactor > 1.5
                                ? "bg-green-500"
                                : healthFactor > 1
                                    ? "bg-yellow-500"
                                    : "bg-red-500"
                            }`}
                        style={{
                            width: `${Math.min(healthFactor * 50, 100)}%`,
                        }}
                    />
                </div>

                <div>
                    <p className="text-sm text-gray-400">Your Debt</p>
                    <p className="text-white font-medium">
                        {Number(debt) / 1e18}
                    </p>
                </div>

                <div>
                    <p className="text-sm text-gray-400">Max Borrow</p>
                    <p className="text-green-400 font-medium">
                        {maxBorrow / 1e18}
                    </p>
                </div>
            </div>

            {/* Deposit Collateral */}
            <div className="space-y-2">
                <input
                    type="number"
                    placeholder="Collateral amount"
                    value={collateralAmount}
                    onChange={(e) => setCollateralAmount(e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-black/40 border border-white/10 text-white"
                />
                <button
                    onClick={handleDepositCollateral}
                    className="w-full bg-blue-500 hover:opacity-90 rounded-lg py-2 text-white"
                >
                    Deposit Collateral
                </button>
            </div>

            {/* Borrow */}
            <div className="space-y-2">
                <input
                    type="number"
                    placeholder="Borrow amount"
                    value={borrowAmount}
                    onChange={(e) => setBorrowAmount(e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-black/40 border border-white/10 text-white"
                />

                {borrowAmount && (
                    <div className="text-sm mt-2">
                        <p className="text-gray-400">Health After Borrow</p>
                        <p
                            className={`font-medium ${simulatedHealthFactor > 1.5
                                    ? "text-green-400"
                                    : simulatedHealthFactor > 1
                                        ? "text-yellow-400"
                                        : "text-red-500"
                                }`}
                        >
                            {simulatedHealthFactor.toFixed(2)}
                        </p>
                    </div>
                )}


                {borrowTooHigh && (
                    <p className="text-red-400 text-sm">
                        Amount exceeds max borrow limit
                    </p>
                )}

                <button
                    disabled={borrowDisabled}
                    onClick={handleBorrow}
                    className="w-full bg-green-500 disabled:bg-gray-600 hover:opacity-90 rounded-lg py-2 text-white"
                >
                    Borrow
                </button>

            </div>

            {/* Repay */}
            <div className="space-y-2">
                <input
                    type="number"
                    placeholder="Repay amount"
                    value={repayAmount}
                    onChange={(e) => setRepayAmount(e.target.value)}
                    className="w-full px-4 py-2 rounded-lg bg-black/40 border border-white/10 text-white"
                />
                <button
                    onClick={handleRepay}
                    className="w-full bg-red-500 hover:opacity-90 rounded-lg py-2 text-white"
                >
                    Repay
                </button>
            </div>


        </div>
    );
}
