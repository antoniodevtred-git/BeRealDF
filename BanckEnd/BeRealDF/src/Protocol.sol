// SPDX-License-Identier: MIT
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract Protocol is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stableToken;
    IERC20 public immutable collateralToken;

    uint256 public immutable collateralRatio;
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public totalSupplied;

    //Structs
    struct LenderInfo {
        uint256 amountSupplied;       // Total amount deposited
        uint256 depositTimestamp;     // Last deposit time
    }
    //Mapings
    mapping(address => LenderInfo) public lenders;

    //Events
    event Deposited(address indexed lender, uint256 amount);
    event Withdrawn(address indexed lender, uint256 amount);


    //Modifiers
    constructor(
        address _stableToken,
        address _collateralToken,
        uint256 _collateralRatio,
        address _owner
    ) Ownable(_owner) {
        require(_stableToken != address(0), "1");
        require(_collateralToken != address(0), "2");
        require(_collateralRatio >= 5000 && _collateralRatio <= 9500, "3");

        stableToken = IERC20(_stableToken);
        collateralToken = IERC20(_collateralToken);
        collateralRatio = _collateralRatio;
    }

    /**
     * @notice Allows a lender to deposit stable tokens into the protocol.
     * @param amount The amount of tokens to deposit.
     * @dev The user must approve the protocol to transfer tokens before calling this.
     * Emits a {Deposited} event.
     */
    function deposit(uint256 amount) external nonReentrant {
        // ✅ Checks
        require(amount > 0, "4"); 

        // ✅ Effects
        // Update lender data
        lenders[msg.sender].amountSupplied += amount;
        lenders[msg.sender].depositTimestamp = block.timestamp;
        totalSupplied += amount;

        // ✅ Interaction
        // Transfer stable tokens from the lender to the protocol
        require(stableToken.transferFrom(msg.sender, address(this), amount), "5");


        emit Deposited(msg.sender, amount);
    }

    /**
    * @notice Allows a lender to withdraw their supplied stable tokens.
    * @param amount The amount of tokens to withdraw.
    * @dev Reverts if the lender does not have enough balance or amount is zero.
    * Emits a {Withdrawn} event.
    */
    function withdraw(uint256 amount) external nonReentrant {
        // ✅ Checks
        require(amount > 0, "6");
        require(lenders[msg.sender].amountSupplied >= amount, "7");

        // ✅ Effects
        lenders[msg.sender].amountSupplied -= amount;
        totalSupplied -= amount;

        // ✅ Interactions
        stableToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }


    /**
     * @notice Returns the total amount supplied by a lender.
     * @param lender The address of the lender.
     * @return amountSupplied The total stable tokens deposited by the lender.
     */
    function getLenderBalance(address lender) external view returns (uint256 amountSupplied) {
        return lenders[lender].amountSupplied;
    }


}

