import { useAccount, useConnect, useDisconnect } from "wagmi"
import { injected } from "wagmi/connectors"

export default function Header() {
  const { address, isConnected } = useAccount()
  const { connect, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  return (
    <header className="w-full border-b border-white/10 backdrop-blur">
      <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-wide">
          BeReal DeFi
        </h1>

        <div className="text-sm">
          {isConnected ? (
            <div className="flex items-center gap-3">
              <span className="px-3 py-1 rounded-full bg-emerald-500/10 text-emerald-400">
                {address?.slice(0, 6)}...{address?.slice(-4)}
              </span>

              <button
                onClick={() => disconnect()}
                className="text-gray-400 hover:text-white transition"
              >
                Disconnect
              </button>
            </div>
          ) : (
            <button
              onClick={() => connect({ connector: injected() })}
              disabled={isPending}
              className="px-4 py-2 rounded-lg bg-primary text-white hover:opacity-90 transition"
            >
              {isPending ? "Connecting..." : "Connect wallet"}
            </button>
          )}
        </div>
      </div>
    </header>
  )
}
