// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Protocol.sol";
import "../src/MockToken.sol";

contract ProtocolLenderTest is Test {
    Protocol protocol;
    MockToken stableToken;
    MockToken collateralToken;

    address lender = address(0x123);
    address borrower = address(0x234);


    event CollateralDeposited(address indexed borrower, uint256 amount);

    uint256 initialSupply = 1_000_000 ether;
    uint256 depositAmount = 1_000 ether;

    function setUp() public {
        stableToken = new MockToken("Stable", "USDC", 6, initialSupply);
        collateralToken = new MockToken("Collateral", "WETH", 18, initialSupply);

        // Deploy Protocol contract
        protocol = new Protocol(
            address(stableToken),
            address(collateralToken),
            8000,   // 80% collateral ratio
            address(this) // owner
        );

        // Transfer collateralToken to borrower
        collateralToken.transfer(borrower, 1000 ether);

        // Transfer stableTokens to lender and approve protocol
        stableToken.transfer(lender, depositAmount);
        vm.prank(lender);
        stableToken.approve(address(protocol), depositAmount);
    }

    function testDeposit() public {
        vm.prank(lender); // simulate lender call

        vm.expectEmit(true, false, false, true);
        emit Protocol.Deposited(lender, depositAmount);

        protocol.deposit(depositAmount);

        // Check internal storage
        (uint256 amountSupplied, uint256 timestamp) = protocol.lenders(lender);
        assertEq(amountSupplied, depositAmount, "Lender deposit not recorded correctly");
        assertEq(protocol.totalSupplied(), depositAmount, "Total supplied incorrect");

        // Check protocol token balance
        assertEq(stableToken.balanceOf(address(protocol)), depositAmount);
    }

    function testDepositZeroReverts() public {
        vm.prank(lender);
        vm.expectRevert(bytes("4"));
        protocol.deposit(0);
    }

        function testWithdraw() public {
        // First deposit
        vm.prank(lender);
        protocol.deposit(depositAmount);

        // Then withdraw half
        uint256 withdrawAmount = depositAmount / 2;
        vm.prank(lender);
        vm.expectEmit(true, false, false, true);
        emit Protocol.Withdrawn(lender, withdrawAmount);
        protocol.withdraw(withdrawAmount);

        (uint256 remaining, ) = protocol.lenders(lender);
        assertEq(remaining, depositAmount - withdrawAmount);
        assertEq(protocol.totalSupplied(), depositAmount - withdrawAmount);
        assertEq(stableToken.balanceOf(lender), withdrawAmount); // Half returned
    }

    function testWithdrawTooMuchReverts() public {
        vm.prank(lender);
        protocol.deposit(depositAmount);

        vm.prank(lender);
        vm.expectRevert(bytes("7"));
        protocol.withdraw(depositAmount + 1);
    }

    function testWithdrawZeroReverts() public {
        vm.prank(lender);
        vm.expectRevert(bytes("6"));
        protocol.withdraw(0);
    }

    function testGetLenderBalance() public {
        vm.startPrank(lender);
        stableToken.approve(address(protocol), depositAmount);
        protocol.deposit(depositAmount);
        vm.stopPrank();

        uint256 balance = protocol.getLenderBalance(lender);
        assertEq(balance, depositAmount, "Lender balance mismatch");
    }

    function testDepositCollateral() public {
        vm.startPrank(borrower);

        uint256 amount = 500 ether;

        // Approve the protocol to spend collateral
        collateralToken.approve(address(protocol), amount);

        // Expect event
        vm.expectEmit(true, true, false, true);
        emit Protocol.CollateralDeposited(borrower, amount);

        // Call depositCollateral
        protocol.depositCollateral(amount);

        // Check borrower's internal state
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.collateralDeposited, amount, "Collateral not updated");

        // Check balance in the protocol
        assertEq(collateralToken.balanceOf(address(protocol)), amount);

        vm.stopPrank();
    }

    function testDepositCollateral_RevertsIfAmountZero() public {
        vm.startPrank(borrower);

        vm.expectRevert(bytes("8"));
        protocol.depositCollateral(0);

        vm.stopPrank();
    }

    function testDepositCollateral_RevertsIfNoApproval() public {
        uint256 amount = 500 ether;

        vm.startPrank(borrower);

        vm.expectRevert(); // SafeERC20 will revert on failed transferFrom
        protocol.depositCollateral(amount);

        vm.stopPrank();
    }

    function testDepositCollateral_RevertsIfInsufficientBalance() public {
        uint256 amount = 2_000_000 ether; // more than user has

        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), amount);

        vm.expectRevert(); // Will revert on transferFrom due to insufficient balance
        protocol.depositCollateral(amount);

        vm.stopPrank();
    }

    function testBorrow_success() public {
        uint256 depositCollateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether; // With 80% collateral ratio

        // Setup: borrower deposita colateral
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), depositCollateralAmount);
        protocol.depositCollateral(depositCollateralAmount);

        // Setup: lender deposita liquidez
        vm.stopPrank();
        vm.startPrank(lender);
        protocol.deposit(1000 * 1e6); // 1000 USDC con 6 decimales

        // Borrow
        vm.stopPrank();
        vm.startPrank(borrower);

        vm.expectEmit(true, false, false, true);
        emit Protocol.Borrowed(borrower, borrowAmount);

        protocol.borrow(borrowAmount);

        // Assert: balances y estado interno
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, borrowAmount, "Borrowed amount mismatch");
        assertEq(stableToken.balanceOf(borrower), borrowAmount, "Borrower didn't receive funds");

        vm.stopPrank();
    }

    function testBorrow_revertIfAmountZero() public {
        vm.prank(borrower);

        vm.expectRevert(bytes("9"));
        protocol.borrow(0);
    }

    function testBorrow_revertIfNoCollateral() public {
        // Add liquidity to the pool
        vm.prank(lender);
        protocol.deposit(1_000 * 1e6);

        vm.prank(borrower);
        vm.expectRevert(bytes("10")); // exceeds collateral limit
        protocol.borrow(100 ether);
    }

    function testBorrow_revertIfExceedsCollateralLimit() public {
        // Borrower deposits collateral
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), 100 ether);
        protocol.depositCollateral(100 ether);
        vm.stopPrank();

        // Lender provides liquidity
        vm.prank(lender);
        protocol.deposit(1_000 * 1e6);

        // 80% of 100 = 80 max
        vm.prank(borrower);
        vm.expectRevert(bytes("11"));
        protocol.borrow(81 ether);
    }

    function testBorrow_revertIfInsufficientLiquidity() public {
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), 1_000 ether);
        protocol.depositCollateral(1_000 ether);
        vm.stopPrank();

        // No lender deposit here

        vm.prank(borrower);
        vm.expectRevert(bytes("12"));
        protocol.borrow(800 ether);
    }

}

