// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MarketFactory.sol";
import "../src/MockToken.sol";

contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();

        // ---- Deploy tokens ----
        MockToken collateral = new MockToken(
            "Mock ETH",
            "mETH",
            18,
            1_000_000 
        );

        MockToken stable = new MockToken(
            "Mock USD",
            "mUSD",
            6,
            1_000_000 ether * 1e6
        );

        // ---- Deploy factory ----
        MarketFactory factory = new MarketFactory(msg.sender);

        // ---- Market params ----
        uint256 collateralRatio = 8000; // 80%

        // ---- Create market ----
        address market = factory.createMarket(
            address(stable),
            address(collateral),
            collateralRatio
        );

        console.log("Collateral:", address(collateral));
        console.log("Stable:", address(stable));
        console.log("Factory:", address(factory));
        console.log("Market:", market);

        vm.stopBroadcast();
    }
}
