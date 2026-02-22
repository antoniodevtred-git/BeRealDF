import { useReadContract } from "wagmi";
import { marketFactoryContract } from "../contracts/marketFactory";

export function useMarkets() {
  const { data, isLoading, error } = useReadContract({
    ...marketFactoryContract,
    functionName: "getAllMarkets",
  });

  return {
    markets: (data ?? []) as readonly any[], // temporal
    isLoading,
    error,
  };
}
