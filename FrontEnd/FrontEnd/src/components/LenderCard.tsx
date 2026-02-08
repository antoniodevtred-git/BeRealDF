import { useAccount } from "wagmi"

export default function LenderCard() {
  const { isConnected } = useAccount()

  return (
    <div className="w-full max-w-md rounded-2xl bg-white/5 border border-white/10 p-8 backdrop-blur">
      <h2 className="text-xl font-semibold mb-4">Lend Stablecoins</h2>

      {!isConnected ? (
        <p className="text-sm text-gray-400">
          Connect your wallet to start lending.
        </p>
      ) : (
        <div className="space-y-4">
          <input
            type="number"
            placeholder="Amount"
            className="w-full rounded-lg bg-black/30 border border-white/10 px-4 py-2 text-white"
          />

          <button className="w-full rounded-lg bg-primary py-2 font-medium hover:opacity-90">
            Deposit
          </button>
        </div>
      )}
    </div>
  )
}
