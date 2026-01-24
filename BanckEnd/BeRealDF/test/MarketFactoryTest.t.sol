// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MarketFactory.sol";
import "../src/Protocol.sol";
import "../src/MockToken.sol";


contract MarketFactoryTest is Test {
    MarketFactory factory;
    MockToken stableToken;
    MockToken collateralToken;

    address user = address(0x123);
    uint256 initialSupply = 1_000_000 ether;

    function setUp() public {
        // Deploy mock tokens
        stableToken = new MockToken("Stable", "USDC", 6, initialSupply);
        collateralToken = new MockToken("Collateral", "WETH", 18, initialSupply);

        // Deploy factory
        factory = new MarketFactory();
    }

    function testCreateMarket() public {
        vm.startPrank(user); // Simulate msg.sender = user

        uint256 collateralRatio = 8000; // 80%

        // Create new protocol via factory
        address protocolAddr = factory.createMarket(
            address(stableToken),
            address(collateralToken),
            collateralRatio
        );

        assertTrue(protocolAddr != address(0), "Protocol address should not be zero");

        // Fetch all created markets
        MarketFactory.MarketInfo[] memory createdMarkets = factory.getAllMarkets();
        assertEq(createdMarkets.length, 1, "One market should be created");

        // Validate stored market metadata
        assertEq(createdMarkets[0].protocol, protocolAddr, "Protocol address mismatch");
        assertEq(createdMarkets[0].stableToken, address(stableToken), "Stable token mismatch");
        assertEq(createdMarkets[0].collateralToken, address(collateralToken), "Collateral token mismatch");
        assertEq(createdMarkets[0].collateralRatio, collateralRatio, "Collateral ratio mismatch");

        // Validate deployed Protocol contract state
        Protocol protocol = Protocol(protocolAddr);
        assertEq(address(protocol.stableToken()), address(stableToken));
        assertEq(address(protocol.collateralToken()), address(collateralToken));
        assertEq(protocol.collateralRatio(), collateralRatio);
        assertEq(protocol.owner(), user);

        vm.stopPrank();
    }
}
