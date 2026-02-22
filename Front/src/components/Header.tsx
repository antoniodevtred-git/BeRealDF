import { useAccount } from "wagmi"
import { ConnectWallet } from "./WalletButton"

export default function Header() {
  const { address, isConnected } = useAccount()

  return (
    <header className="w-full border-b border-white/10 backdrop-blur">
      <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <h1 className="text-xl font-semibold tracking-wide">
          BeReal DeFi
        </h1>

        <div className="flex items-center gap-4">
          {isConnected && (
            <span className="px-3 py-1 rounded-full bg-emerald-500/10 text-emerald-400 text-sm">
              {address?.slice(0, 6)}...{address?.slice(-4)}
            </span>
          )}

          <ConnectWallet />
        </div>
      </div>
    </header>
  )
}
