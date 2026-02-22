import { useAccount, useConnect, useDisconnect } from "wagmi";
import { injected } from "wagmi/connectors";

export function ConnectWallet() {
  const { address, isConnected } = useAccount();
  const { connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected) {
    return (
      <button
        onClick={() => disconnect()}
        className="px-4 py-2 rounded-lg bg-red-500 text-white"
      >
        Disconnect
      </button>
    );
  }

  return (
    <button
      onClick={() => connect({ connector: injected() })}
      disabled={isPending}
      className="px-4 py-2 rounded-lg bg-primary text-white hover:opacity-90"
    >
      {isPending ? "Connecting..." : "Connect Wallet"}
    </button>
  );
}
