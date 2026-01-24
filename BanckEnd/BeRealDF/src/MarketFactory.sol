// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Protocol.sol";

/**
 * @title MarketFactory
 * @notice Factory contract to deploy new lending protocol markets (Protocol instances)
 */
contract MarketFactory {
    /// @notice Struct to store market metadata
    struct MarketInfo {
        address protocol;
        address stableToken;
        address collateralToken;
        uint256 collateralRatio;
    }

    /// @notice Array of all created markets
    MarketInfo[] public markets;

    /// @notice Emitted when a new market (Protocol) is deployed
    event MarketCreated(
        address indexed protocol,
        address indexed stableToken,
        address indexed collateralToken,
        uint256 collateralRatio
    );

    /**
     * @notice Deploys a new lending market (Protocol)
     * @dev Deploys a new Protocol contract using the given tokens and ratio
     * @param _stableToken Address of the stable token (e.g., USDC)
     * @param _collateralToken Address of the collateral token (e.g., WETH)
     * @param _collateralRatio Collateral ratio in basis points (e.g., 8000 = 80%)
     * @return Address of the deployed Protocol contract
     */
    function createMarket(
        address _stableToken,
        address _collateralToken,
        uint256 _collateralRatio
    ) external returns (address) {
        require(_stableToken != address(0), "Stable token is zero");
        require(_collateralToken != address(0), "Collateral token is zero");
        require(_stableToken != _collateralToken, "Tokens must be different");

        // Deploy new Protocol contract
        Protocol newProtocol = new Protocol(
            _stableToken,
            _collateralToken,
            _collateralRatio,
            msg.sender // Pass the caller as owner
        );

        // Store market metadata
        markets.push(MarketInfo({
            protocol: address(newProtocol),
            stableToken: _stableToken,
            collateralToken: _collateralToken,
            collateralRatio: _collateralRatio
        }));

        emit MarketCreated(
            address(newProtocol),
            _stableToken,
            _collateralToken,
            _collateralRatio
        );

        return address(newProtocol);
    }

    /**
     * @notice Returns all created markets with full metadata
     * @return Array of MarketInfo structs
     */
    function getAllMarkets() external view returns (MarketInfo[] memory) {
        return markets;
    }

    /**
     * @notice Returns only the addresses of deployed Protocol contracts
     * @return Array of protocol contract addresses
     */
    function getAllMarketAddresses() external view returns (address[] memory) {
        address[] memory result = new address[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            result[i] = markets[i].protocol;
        }
        return result;
    }
}
