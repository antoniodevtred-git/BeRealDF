import { createConfig, http } from "wagmi";
import { mainnet, sepolia } from "wagmi/chains";
import { injected } from "wagmi/connectors";

export const config = createConfig({
  chains: [sepolia], // o mainnet luego
  connectors: [
    injected(), // MetaMask, Brave, etc
  ],
  transports: {
    [sepolia.id]: http(),
  },
});
