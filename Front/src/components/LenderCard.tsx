import { useState, useEffect } from "react";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { parseUnits } from "viem";
import { formatUnits } from "viem";


import { protocolAbi, erc20Abi } from "@/contracts";

interface Props {
  protocolAddress: `0x${string}`;
}

export default function LenderCard({ protocolAddress }: Props) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");

  // -------- 1️⃣ Read stable token address --------
  const { data: stableToken } = useReadContract({
    address: protocolAddress,
    abi: protocolAbi,
    functionName: "stableToken",
  });

  // -------- 2️⃣ Read user balance --------
  const { data: balance } = useReadContract({
    address: stableToken as `0x${string}`,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!stableToken && !!address },
  });

  // -------- 3️⃣ Read allowance --------
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: stableToken as `0x${string}`,
    abi: erc20Abi,
    functionName: "allowance",
    args: address ? [address, protocolAddress] : undefined,
    query: { enabled: !!stableToken && !!address },
  });

  // -------- Write hooks --------
  const { writeContractAsync } = useWriteContract();

  if (!address) return null;

  const parsedAmount =
    amount && stableToken
      ? parseUnits(amount, 18)
      : undefined;

    const needsApproval =
    parsedAmount !== undefined &&
    allowance !== undefined
      ? parsedAmount > allowance
      : true;
    
  const handleApprove = async () => {
    if (!parsedAmount || !stableToken) return;

    await writeContractAsync({
      address: stableToken as `0x${string}`,
      abi: erc20Abi,
      functionName: "approve",
      args: [protocolAddress, parsedAmount],
    });

    await refetchAllowance();
  };

  const handleDeposit = async () => {
    if (!parsedAmount) return;

    await writeContractAsync({
      address: protocolAddress,
      abi: protocolAbi,
      functionName: "deposit",
      args: [parsedAmount],
    });

    setAmount("");
  };

  return (
    <div className="bg-white/5 border border-white/10 rounded-2xl p-6 w-80 space-y-4">
      <h3 className="text-lg font-semibold">Supply Stablecoins</h3>

      <div>
        <p className="text-sm text-gray-400">Wallet Balance</p>
        <p className="text-white">
        {balance ? formatUnits(balance, 18) : "0"}
        </p>
      </div>

      <input
        type="number"
        placeholder="Amount"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        className="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-white"
      />

      {needsApproval ? (
        <button
          onClick={handleApprove}
          className="w-full bg-yellow-500 hover:opacity-90 text-black py-2 rounded-lg"
        >
          Approve
        </button>
      ) : (
        <button
          onClick={handleDeposit}
          className="w-full bg-primary hover:opacity-90 text-white py-2 rounded-lg"
        >
          Deposit
        </button>
      )}
    </div>
  );
}
