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
    address public feeRecipient;
    uint256 public protocolFeeBps;

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
        address _owner,
        address _feeRecipient,
        uint256 _protocolFeeBps
    ) Ownable(_owner) {
        require(_stableToken != address(0), "1");
        require(_collateralToken != address(0), "2");
        require(_collateralRatio >= 5000 && _collateralRatio <= 9500, "3");

        stableToken = IERC20(_stableToken);
        collateralToken = IERC20(_collateralToken);
        collateralRatio = _collateralRatio;
        feeRecipient = _feeRecipient;
        protocolFeeBps = _protocolFeeBps;

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
    * @notice Allows a borrower to repay part of their loan including interest and protocol fee.
    * @param principalAmount The amount of principal (not including interest or fees) to repay.
    * @dev The borrower must approve the protocol to transfer the total repayment amount.
    *      The total amount transferred includes:
    *      - `principalAmount` (reduces debt),
    *      - interest (goes to the protocol pool),
    *      - protocol fee (transferred to the feeRecipient).
    * Emits a {Repaid} event with the amount of principal repaid.
    */
    function repay(uint256 principalAmount) external nonReentrant {
        require(principalAmount > 0, "9");

        BorrowerInfo storage info = borrowers[msg.sender];
        require(info.amountBorrowed > 0, "13");
        require(principalAmount <= info.amountBorrowed, "14");

        // Calculate total interest accrued since borrow
        uint256 fullInterest = _calculateInterest(msg.sender);

        // Total amount borrower needs to pay in this call
        uint256 totalToPay = principalAmount + fullInterest;

        // ---- Effects ----
        info.amountBorrowed -= principalAmount;
        info.amountRepaid += principalAmount;

        bool loanFullyRepaid = info.amountBorrowed == 0;

        // If loan is fully repaid, reset timestamps and update state
        if (loanFullyRepaid) {
            info.borrowTimestamp = 0;
            info.lastIteration = block.timestamp;
        }

        // ---- Interactions ----
        stableToken.safeTransferFrom(msg.sender, address(this), totalToPay);

        // Transfer protocol fee to feeRecipient only if the loan is fully repaid
        if (loanFullyRepaid && fullInterest > 0) {
            uint256 protocolFee = (fullInterest * protocolFeeBps) / BASIS_POINTS;
            stableToken.safeTransfer(feeRecipient, protocolFee);
        }

        emit Repaid(msg.sender, principalAmount);
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

    /**
    * @notice Determines the loan quarter based on elapsed time since borrowing.
    * @param timeElapsed Time passed since the loan was taken (in seconds).
    * @return quarter The loan quarter:
    *         1 = 0–3 months,
    *         2 = 3–6 months,
    *         3 = 6–9 months,
    *         4 = 9–12 months.
    */
    function _getQuarter(uint256 timeElapsed) internal pure returns (uint8) {
        if (timeElapsed <= 90 days) return 1;
        if (timeElapsed <= 180 days) return 2;
        if (timeElapsed <= 270 days) return 3;
        return 4; // up to 12 months
    }

    /**
    * @notice Returns the interest rate and protocol fee for a given loan quarter.
    * @param quarter The loan quarter (1 to 4).
    * @return interestBP Interest rate expressed in basis points.
    * @return feeBP Protocol fee expressed in basis points, applied over the interest.
    *
    * Quarter rules:
    * - Q1 (0–3 months):   4.5% interest, 1% fee
    * - Q2 (3–6 months):   8% interest,   1.5% fee
    * - Q3 (6–9 months):   10.5% interest, 2% fee
    * - Q4 (9–12 months):  13% interest,  2.5% fee
    */
    function _getInterestAndFee(uint8 quarter) internal pure returns (uint256 interestBP, uint256 feeBP) {
        if (quarter == 1) return (450, 100);   
        if (quarter == 2) return (800, 150);   
        if (quarter == 3) return (1050, 200);  
        return (1300, 250);
    }

    /**
    * @notice Calculates the total outstanding debt for a borrower including interest.
    * @param borrower Address of the borrower.
    * @return totalDebt The sum of principal plus accrued interest (protocol fee excluded).
    * @dev This function does NOT include the protocol fee.
    *      It is useful for UI display or liquidation checks.
    */
    function calculateTotalDebt(address borrower) public view returns (uint256) {
        BorrowerInfo storage info = borrowers[borrower];
        if (info.amountBorrowed == 0) return 0;

        uint256 timeElapsed = block.timestamp - info.borrowTimestamp;
        uint8 quarter = _getQuarter(timeElapsed);

        (uint256 interestBP, ) = _getInterestAndFee(quarter);

        uint256 interest = (info.amountBorrowed * interestBP) / 10_000;
        return info.amountBorrowed + interest;
    }

    /**
    * @notice Calculates the protocol fee owed by a borrower.
    * @param borrower Address of the borrower.
    * @return feeAmount The protocol fee amount in stable tokens.
    * @dev The fee is calculated as a percentage of the accrued interest,
    *      not of the principal.
    *      This amount is transferred to the `feeRecipient`.
    */
    function _calculateProtocolFee(address borrower) internal view returns (uint256) {
        BorrowerInfo storage info = borrowers[borrower];

        uint256 timeElapsed = block.timestamp - info.borrowTimestamp;
        uint8 quarter = _getQuarter(timeElapsed);

        (uint256 interestBP, uint256 feeBP) = _getInterestAndFee(quarter);

        uint256 interest = (info.amountBorrowed * interestBP) / 10_000;
        return (interest * feeBP) / 10_000;
    }

    /**
    * @notice Calculates the accrued interest for a borrower based on loan duration.
    * @param borrower Address of the borrower.
    * @return interestAmount The interest owed in stable tokens.
    * @dev Interest is calculated using a fixed rate per quarter.
    *      It does not compound and is based on the current borrowed amount.
    */
    function _calculateInterest(address borrower) internal view returns (uint256) {
        BorrowerInfo storage info = borrowers[borrower];

        uint256 timeElapsed = block.timestamp - info.borrowTimestamp;
        uint8 quarter = _getQuarter(timeElapsed);

        (uint256 interestBP, ) = _getInterestAndFee(quarter);
        return (info.amountBorrowed * interestBP) / BASIS_POINTS;
    }

}