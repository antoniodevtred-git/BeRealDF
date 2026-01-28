// SPDX-License-Identier: MIT
pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/forge-std/src/console.sol";


contract Protocol is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stableToken;
    IERC20 public immutable collateralToken;

    uint256 public immutable collateralRatio;
    uint256 public constant BASIS_POINTS = 10_000;
 

    uint256 public totalSupplied;

    //Structs
    struct LenderInfo {
        uint256 amountSupplied;
        uint256 depositTimestamp;
    }

    struct BorrowerInfo {
        uint256 amountBorrowed;
        uint256 initialBorrowAmount;
        uint256 collateralDeposited;
        uint256 borrowTimestamp;
        uint256 lastIteration;
        uint256 amountRepaid;
    }
    
    //Mapings
    mapping(address => LenderInfo) public lenders;
    mapping(address => BorrowerInfo) public borrowers;

    //Events
    event Deposited(address indexed lender, uint256 amount);
    event Withdrawn(address indexed lender, uint256 amount);
    event CollateralDeposited(address indexed borrower, uint256 amount);
    event Borrowed(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed borrower, uint256 repaidAmount, uint256 collateralSeized);

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

    /**
    * @notice Allows a user to deposit collateral tokens to enable borrowing.
    * @param amount The amount of collateral tokens to deposit.
    * @dev The user must approve the protocol to transfer collateral tokens.
    * Emits a {CollateralDeposited} event.
    */
    function depositCollateral(uint256 amount) external nonReentrant {
        // ✅ Checks
        require(amount > 0, "8"); 

        // ✅ Effects
        borrowers[msg.sender].collateralDeposited += amount;
        borrowers[msg.sender].borrowTimestamp = block.timestamp;

        // ✅ Interactions
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, amount);
    }

    /**
    * @notice Returns the full borrower information struct
    * @param borrower Address of the borrower
    */
    function getBorrower(address borrower)
        external
        view
        returns (BorrowerInfo memory)
    {
        return borrowers[borrower];
    }

    /**
    * @notice Allows a borrower to request a loan using deposited collateral.
    * @param amount The amount of stable tokens to borrow.
    * @dev Requires enough collateral and available liquidity in the pool.
    * Emits a {Borrowed} event.
    */
    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "9"); // Amount must be greater than zero

        BorrowerInfo storage info = borrowers[msg.sender];

        require(info.collateralDeposited > 0, "10");

        // Max borrowable = collateral * (collateralRatio / 10000)
        uint256 maxBorrowable = (info.collateralDeposited * collateralRatio) / BASIS_POINTS;

        require(info.amountBorrowed + amount <= maxBorrowable, "11");
        require(amount <= totalSupplied, "12");

        // ✅ Effects
        info.amountBorrowed += amount;
        info.initialBorrowAmount += amount;
        info.borrowTimestamp = block.timestamp;
        info.lastIteration = block.timestamp;
        totalSupplied -= amount;

        // ✅ Interactions
        stableToken.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    /**
     * @notice Allows a borrower to repay their borrowed stable tokens.
     * @param amount The amount of stable tokens to repay.
     * @dev The borrower must approve the protocol to spend tokens beforehand.
     * Emits a {Repaid} event.
     */
    function repay(uint256 amount) external nonReentrant {
        require(amount > 0, "9"); 

        BorrowerInfo storage info = borrowers[msg.sender];
        require(info.amountBorrowed > 0, "13"); 
        require(amount <= info.amountBorrowed, "14"); 

        // Effects
        info.amountBorrowed -= amount;
        info.amountRepaid += amount;


        if (info.amountBorrowed == 0) {
            info.borrowTimestamp = 0;
            info.lastIteration = block.timestamp;
        }

        // Interactions
        stableToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Repaid(msg.sender, amount);
    }

    /**
    * @notice Returns the collateral ratio of a borrower's position.
    * @param borrower The address of the borrower.
    * @return ratio The collateral ratio in basis points (10000 = 100%).
    */
    function getCollateralRatio(address borrower) public view returns (uint256 ratio) {
        BorrowerInfo memory info = borrowers[borrower];

        if (info.amountBorrowed == 0) {
            return type(uint256).max;
        }

        return (info.collateralDeposited * BASIS_POINTS) / info.amountBorrowed;
    }

    /**
    * @notice Checks if a borrower's position is eligible for liquidation.
    * @param borrower The address of the borrower to check.
    * @return True if the position can be liquidated, false otherwise.
    */
    function isLiquidatable(address borrower) public view returns (bool) {
        BorrowerInfo storage info = borrowers[borrower];

        if (info.amountBorrowed == 0) return false;

        uint256 timeSinceBorrow = block.timestamp - info.borrowTimestamp;

        // 1. Loan has passed maximum duration (12 months)
        if (timeSinceBorrow > 365 days) {
            return true;
        }

        // 2. Collateral ratio has dropped below required threshold
        if (getCollateralRatio(borrower) < collateralRatio) {
            return true;
        }

        // 3. Between 6 and 9 months, must have repaid at least 25% of initial loan
        if (timeSinceBorrow > 180 days && timeSinceBorrow <= 270 days) {
            uint256 minRequired = (info.initialBorrowAmount * 25) / 100;
            if (info.amountRepaid < minRequired) {
                return true;
            }
        }

        // 4. Between 9 and 12 months, must have repaid at least 50% of initial loan
        if (timeSinceBorrow > 270 days && timeSinceBorrow <= 365 days) {
            uint256 minRequired = (info.initialBorrowAmount * 50) / 100;
            if (info.amountRepaid < minRequired) {
                return true;
            }
        }

        return false;
    }

    /**
    * @notice Allows anyone to liquidate an undercollateralized borrower's position.
    * @param borrower The address of the borrower to liquidate.
    * @dev Transfers collateral to the liquidator and resets borrower's position.
    */
    function liquidate(address borrower) external nonReentrant {
        BorrowerInfo storage info = borrowers[borrower];

        require(info.amountBorrowed > 0, "13");
        require(isLiquidatable(borrower), "15");
        require(info.amountBorrowed > 0, "16");
        require(info.collateralDeposited > 0, "17");

        uint256 debt = info.amountBorrowed;
        uint256 collateral = info.collateralDeposited;

        // Reset borrower state
        info.amountBorrowed = 0;
        info.collateralDeposited = 0;
        info.borrowTimestamp = 0;
        info.lastIteration = block.timestamp;

        // Transfer stableToken from liquidator to protocol
        stableToken.safeTransferFrom(msg.sender, address(this), debt);

        // Transfer collateral to liquidator
        collateralToken.safeTransfer(msg.sender, collateral);

        emit Liquidated(msg.sender, borrower, debt, collateral);
    }

    function testSetCollateral(address borrower, uint256 amount) external {
    borrowers[borrower].collateralDeposited = amount;
}

}

