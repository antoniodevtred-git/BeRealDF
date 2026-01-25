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

    struct BorrowerInfo {
        uint256 amountBorrowed; // Total amount borrowed
        uint256 collateralDeposited; // Collateral deposited
        uint256 borrowTimestamp; // Time Borrow
        uint256 lastIteration;
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

        if (info.amountBorrowed == 0) {
            info.borrowTimestamp = 0;
            info.lastIteration = block.timestamp;
        }

        // Interactions
        stableToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Repaid(msg.sender, amount);
    }

}

