// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Market.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title MarketFactory
 * @dev Creates and manages lending markets (USDC-WETH, DAI-WBTC, etc)
 */
contract MarketFactory is Ownable {
    constructor() Ownable(msg.sender) {}
    // Struct to hold metadata about each market
    struct MarketInfo {
        address marketAddress;
        address stableToken;
        address collateralToken;
    }

    // All markets created
    MarketInfo[] public markets;

    // Mapping to prevent duplicate pairs
    mapping(bytes32 => address) public getMarket;

    // Events
    event MarketCreated(address indexed market, address indexed stableToken, address indexed collateralToken);

    /**
     * @dev Creates a new lending market with defined tokens and params
     * @param _stableToken Address of the stablecoin (e.g. USDC)
     * @param _collateralToken Address of the collateral token (e.g. WETH)
     * @param _collateralRatio Collateral ratio in BPS (e.g. 8000 = 80%)
     * @param _interestModelAddress Optional interest model address (can be 0x0 for now)
     */
    function createMarket(
        address _stableToken,
        address _collateralToken,
        uint256 _collateralRatio,
        address _interestModelAddress
    ) external onlyOwner returns (address) {
        require(_stableToken != address(0) && _collateralToken != address(0), "Invalid token address");
        require(_stableToken != _collateralToken, "Tokens must differ");
        require(_collateralRatio >= 5000 && _collateralRatio <= 9500, "Invalid collateral ratio"); // Between 50% and 95%

        bytes32 marketId = keccak256(abi.encodePacked(_stableToken, _collateralToken));
        require(getMarket[marketId] == address(0), "Market already exists");

        // Deploy new Market
        Market newMarket = new Market(
            _stableToken,
            _collateralToken,
            _collateralRatio,
            address(this)
        );

        address marketAddr = address(newMarket);
        getMarket[marketId] = marketAddr;

        markets.push(MarketInfo({
            marketAddress: marketAddr,
            stableToken: _stableToken,
            collateralToken: _collateralToken
        }));

        emit MarketCreated(marketAddr, _stableToken, _collateralToken);
        return marketAddr;
    }

    /**
     * @dev Returns all markets
     */
    function getAllMarkets() external view returns (MarketInfo[] memory) {
        return markets;
    }

    /**
     * @dev Returns market address for a stable/collateral pair
     */
    function getMarketAddress(address stable, address collateral) external view returns (address) {
        return getMarket[keccak256(abi.encodePacked(stable, collateral))];
    }

    /**
     * @dev Total number of markets created
     */
    function totalMarkets() external view returns (uint256) {
        return markets.length;
    }
}
