
export const marketFactoryAbi = [
    {
      inputs: [],
      name: "getAllMarkets",
      outputs: [
        {
          components: [
            { name: "protocol", type: "address" },
            { name: "stableToken", type: "address" },
            { name: "collateralToken", type: "address" },
            { name: "collateralRatio", type: "uint256" },
          ],
          type: "tuple[]",
        },
      ],
      stateMutability: "view",
      type: "function",
    },
  ] as const;
  