import MarketFactoryJson from "./abi/MarketFactory.json";
import {  FACTORY_ADDRESS } from "./addresses";

export const marketFactoryContract = {
  address: FACTORY_ADDRESS as `0x${string}`,
  abi: MarketFactoryJson.abi,
};
