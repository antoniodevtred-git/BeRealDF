// SPDX-License-Identier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Market is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stableToken;
    IERC20 public immutable collateralToken;
    uint256 public immutable collateralRatio;

    uint256 public constant BASIS_POINTS = 10_000;

    constructor(
        address _stableToken,
        address _collateralToken,
        uint256 _collateralRatio,
        address _owner
    ) Ownable(_owner) {
        require(_stableToken != address(0), "Invalid stableToken");
        require(_collateralToken != address(0), "Invalid collateralToken");
        require(_collateralRatio >= 5000 && _collateralRatio <= 9500, "Invalid collateralRatio");

        stableToken = IERC20(_stableToken);
        collateralToken = IERC20(_collateralToken);
        collateralRatio = _collateralRatio;
    }
}
