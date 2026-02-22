// src/types/market.ts
export type MarketInfo = {
    protocol: `0x${string}`;
    stableToken: `0x${string}`;
    collateralToken: `0x${string}`;
    collateralRatio: bigint;
  };
  