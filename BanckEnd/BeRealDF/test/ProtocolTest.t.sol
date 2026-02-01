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
    address feeRecipient = address(0xBEEF);


    event CollateralDeposited(address indexed borrower, uint256 amount);
    event Borrowed(address indexed borrower, uint256 amount);


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
            address(this), // owner
            feeRecipient,
            150
        );

        // Transfer collateralToken to borrower
        collateralToken.transfer(borrower, 1000 ether);

        //stableToken.transfer(borrower, 2_000 * 1e6); 

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

    function testDeposit_success() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC (6 decimals)

        // Transfer tokens to lender 
        stableToken.transfer(lender, amount);

        // Lender approve protocol
        vm.startPrank(lender);
        stableToken.approve(address(protocol), amount);

        // Espera el evento
        vm.expectEmit(true, false, false, true);
        emit Protocol.Deposited(lender, amount);

        // call a deposit()
        protocol.deposit(amount);
        vm.stopPrank();

        // Verify state
        (uint256 supplied, ) = protocol.lenders(lender);
        assertEq(supplied, amount, "Lender amount mismatch");

        assertEq(protocol.totalSupplied(), amount, "Total supplied mismatch");

        // Verify amount contract
        assertEq(stableToken.balanceOf(address(protocol)), amount, "Protocol token balance incorrect");
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
        uint256 borrowAmount = 800 * 1e6; // ✅ USDC decimals

        // borrower deposits collateral
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), depositCollateralAmount);
        protocol.depositCollateral(depositCollateralAmount);
        vm.stopPrank();

        // lender provides liquidity
        vm.startPrank(lender);
        protocol.deposit(1000 * 1e6);
        vm.stopPrank();

        // borrower borrows
        vm.startPrank(borrower);

        vm.expectEmit(true, false, false, true);
        emit Borrowed(borrower, borrowAmount);

        protocol.borrow(borrowAmount);

        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, borrowAmount);
        assertEq(stableToken.balanceOf(borrower), borrowAmount);

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

   function testRepay_success() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 * 1e6;
        uint256 repayAmount = borrowAmount;

        // Borrower deposits collateral
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        // Lender deposits stable tokens
        vm.startPrank(lender);
        protocol.deposit(1000 * 1e6); // 1000 USDC
        vm.stopPrank();

        // Borrower borrows
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);

        // Approve repayment
        stableToken.approve(address(protocol), repayAmount);

        // Expect event
        vm.expectEmit(true, false, false, true);
        emit Protocol.Repaid(borrower, repayAmount);

        protocol.repay(repayAmount);

        // Check state
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, 0, "Borrowed amount should be 0");
        assertEq(stableToken.balanceOf(address(protocol)), 1000 * 1e6, "Protocol balance mismatch");

        vm.stopPrank();
    }

    function testRepay_RevertIfAmountZero() public {
        vm.startPrank(borrower);

        vm.expectRevert(bytes("9"));
        protocol.repay(0);

        vm.stopPrank();
    }

    function testRepay_RevertIfNoActiveLoan() public {
    vm.startPrank(borrower);

    uint256 repayAmount = 100 * 1e6;
        stableToken.approve(address(protocol), repayAmount);

        vm.expectRevert(bytes("13"));
        protocol.repay(repayAmount);

        vm.stopPrank();
    }

    function testRepay_RevertIfRepayingTooMuch() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 500 * 1e6;

        // Setup: borrower deposits collateral
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        // Setup: lender adds liquidity
        vm.startPrank(lender);
        protocol.deposit(1000 * 1e6);
        vm.stopPrank();

        // Borrow
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);

        uint256 tooMuch = borrowAmount + 1;
        stableToken.approve(address(protocol), tooMuch);

        vm.expectRevert(bytes("14"));
        protocol.repay(tooMuch);

        vm.stopPrank();
    }

    function testRepay_MakesLoanNoLongerLiquidable() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;

        // Setup: borrower deposits collateral and borrows
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        vm.startPrank(lender);
        stableToken.approve(address(protocol), borrowAmount);
        protocol.deposit(borrowAmount);
        vm.stopPrank();

        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        // Warp to between 9 and 12 months (require at least 50% repaid)
        vm.warp(block.timestamp + 300 days);

        // Borrower repays 60%
        uint256 repayAmount = (borrowAmount * 60) / 100;
        stableToken.transfer(borrower, repayAmount);
        vm.startPrank(borrower);
        stableToken.approve(address(protocol), repayAmount);
        protocol.repay(repayAmount);
        vm.stopPrank();

        // Should no longer be liquidable
        bool liquidable = protocol.isLiquidatable(borrower);
        assertFalse(liquidable, "Loan should not be liquidable after enough repayment");
    }

    function testRepay_TransfersFeeToFeeRecipient() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 * 1e6;

        // Deposita collateral
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        // Lender deposita fondos
        vm.startPrank(lender);
        protocol.deposit(1000 * 1e6);
        vm.stopPrank();

        // Borrower toma préstamo
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);

        // Adelanta el tiempo para que haya interés y fee
        vm.warp(block.timestamp + 95 days); // Q2 → 8% interés, 1.5% fee

        // Calcula deuda + fee
        uint256 interest = (borrowAmount * 800) / 10_000;
        uint256 fee = (interest * 150) / 10_000;
        uint256 totalRepay = borrowAmount + interest + fee;

        // Asigna fondos para pagar y aprueba
        stableToken.transfer(borrower, totalRepay);
        stableToken.approve(address(protocol), totalRepay + 1 ether);


        // Registra balance anterior del feeRecipient
        uint256 before = stableToken.balanceOf(feeRecipient);

        // Repago
        protocol.repay(borrowAmount);

        // Verifica que fee fue transferido
        uint256 afterBalance = stableToken.balanceOf(feeRecipient);
        assertEq(afterBalance - before, fee, "FeeRecipient debe recibir el fee");
        vm.stopPrank();
    }


    function testLiquidate_success() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;

        // Setup: borrower deposit collaterall and borrow
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        vm.startPrank(lender);
        protocol.deposit(1000 ether);
        vm.stopPrank();

        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        // Manipulamos el estado para forzar la liquidación (por ejemplo, bajamos el ratio)
        vm.warp(block.timestamp + 370 days); // Simulamos vencimiento del préstamo

        // Approve liquidator
        address liquidator = address(0x999);
        stableToken.transfer(liquidator, borrowAmount);
        vm.startPrank(liquidator);
        stableToken.approve(address(protocol), borrowAmount);

        // wait event
        vm.expectEmit(true, true, true, true);
        emit Protocol.Liquidated(liquidator, borrower, borrowAmount, collateralAmount);

        // Build liquidation
        protocol.liquidate(borrower);

        // Check: borrower reset
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, 0, "Borrow not reset");
        assertEq(info.collateralDeposited, 0, "Collateral not reset");

        // Check: liquidator recive colateral
        assertEq(collateralToken.balanceOf(liquidator), collateralAmount);

        vm.stopPrank();
    }

    function testLiquidate_RevertsIfNoLoanExists() public {
        vm.expectRevert(bytes("13")); 
        protocol.liquidate(borrower);
    }

    function testLiquidate_RevertsIfNotLiquidable() public {
        // Setup: borrower deposits collateral and borrows
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;

        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        vm.startPrank(lender);
        stableToken.approve(address(protocol), borrowAmount);
        protocol.deposit(borrowAmount);
        vm.stopPrank();

        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        // Simulate a short time (still not liquidable)
        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(bytes("15"));
        protocol.liquidate(borrower);
    }

    function testLiquidate_LowCollateralRatio() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;

        //  Setup: Borrower deposits collateral 
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        //  Setup: Lender provides liquidity 
        stableToken.transfer(lender, borrowAmount);
        vm.startPrank(lender);

        stableToken.approve(address(protocol), borrowAmount);
        protocol.deposit(borrowAmount);
        vm.stopPrank();

        //  Borrower borrows funds 
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        //  Simulate drop in collateral value 
        protocol.testSetCollateral(borrower, 600 ether);

        //  Debug logs (opcional, puedes quitar después) 
        bytes32 base = keccak256(abi.encode(borrower, uint256(5))); // slot 5 for `borrowers`
        bytes32 loaded = vm.load(address(protocol), bytes32(uint256(base) + 2));
        console2.log("Collateral after store:", uint256(loaded));

        bool liquidable = protocol.isLiquidatable(borrower);
        console2.log("Is liquidatable?", liquidable);
        require(liquidable, "Should be liquidatable now");

        //  Perform liquidation 
        vm.startPrank(lender);
        stableToken.approve(address(protocol), borrowAmount); 
        vm.expectEmit(true, true, false, false);
        emit Protocol.Liquidated(lender, borrower, borrowAmount, 600 ether);
        protocol.liquidate(borrower);
        vm.stopPrank();

        //  Check borrower state reset 
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, 0, "Loan not cleared after liquidation");
        assertEq(info.collateralDeposited, 0, "Collateral not cleared after liquidation");
    }

    function testLiquidate_RevertsIfRepaidLessThan25PercentBetween6And9Months() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;

        // ===== Setup borrower =====
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        // ===== Setup lender =====
        vm.startPrank(lender);
        stableToken.approve(address(protocol), borrowAmount);
        protocol.deposit(borrowAmount);
        vm.stopPrank();

        // ===== Borrow funds =====
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        // Simulate passage of time: 7 months (between 6 and 9)
        vm.warp(block.timestamp + 210 days);

        // Liquidator setup
        address liquidator = lender; // or use another address if you prefer
        stableToken.transfer(liquidator, borrowAmount); // Ensure liquidator has enough
        vm.startPrank(liquidator);
        stableToken.approve(address(protocol), borrowAmount);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit Protocol.Liquidated(liquidator, borrower, borrowAmount, collateralAmount);

        // Perform liquidation
        protocol.liquidate(borrower);
        vm.stopPrank();

        // Post-check
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, 0);
        assertEq(info.collateralDeposited, 0);
    }
    
    function testLiquidate_RevertsIfRepaidLessThan50PercentBetween9And12Months() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;
        uint256 repaidAmount = 300 ether; // Menos del 50%

        // ===== Setup borrower =====
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        // ===== Setup lender and provide liquidity =====
        vm.startPrank(lender);
        stableToken.approve(address(protocol), 1000 ether);
        protocol.deposit(1000 ether);
        vm.stopPrank();

        // ===== Borrow funds =====
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        // ===== Repay only 300 ether (menos del 50%) =====
        stableToken.transfer(borrower, repaidAmount);
        vm.startPrank(borrower);
        stableToken.approve(address(protocol), repaidAmount);
        protocol.repay(repaidAmount);
        vm.stopPrank();

        // Simula entre 9 y 12 meses (ej: 300 días)
        vm.warp(block.timestamp + 300 days);

        // ===== Liquidator setup =====
        address liquidator = address(0x999);
        stableToken.transfer(liquidator, borrowAmount - repaidAmount); // Solo necesita cubrir lo restante
        vm.startPrank(liquidator);
        stableToken.approve(address(protocol), borrowAmount - repaidAmount);

        // Esperamos el evento
        vm.expectEmit(true, true, true, true);
        emit Protocol.Liquidated(liquidator, borrower, borrowAmount - repaidAmount, collateralAmount);

        // ===== Liquidate =====
        protocol.liquidate(borrower);
        vm.stopPrank();

        // ===== Check borrower reset =====
        Protocol.BorrowerInfo memory info = protocol.getBorrower(borrower);
        assertEq(info.amountBorrowed, 0, "Borrow not cleared");
        assertEq(info.collateralDeposited, 0, "Collateral not cleared");
    }

    function testLiquidate_RevertsIfRepaidAtLeast50PercentBetween9And12Months() public {
        uint256 collateralAmount = 1000 ether;
        uint256 borrowAmount = 800 ether;
        uint256 repaidAmount = 400 ether; // Exactly 50% repayment

        // ===== Setup: borrower deposits collateral =====
        vm.startPrank(borrower);
        collateralToken.approve(address(protocol), collateralAmount);
        protocol.depositCollateral(collateralAmount);
        vm.stopPrank();

        // ===== Setup: lender deposits liquidity =====
        vm.startPrank(lender);
        stableToken.approve(address(protocol), 1000 ether);
        protocol.deposit(1000 ether);
        vm.stopPrank();

        // ===== Borrower borrows funds =====
        vm.startPrank(borrower);
        protocol.borrow(borrowAmount);
        vm.stopPrank();

        // ===== Borrower repays 50% of the loan + interest + fee =====
        uint256 totalDebt = borrowAmount; // 800 ether
        uint256 interest = (totalDebt * 800) / 10_000; // 8% anual
        uint256 fee = (interest * 150) / 10_000;       // 1.5% del interés
        uint256 totalRepay = repaidAmount + interest + fee;

        stableToken.transfer(borrower, totalRepay);
        vm.startPrank(borrower);
        stableToken.approve(address(protocol), totalRepay);
        protocol.repay(repaidAmount);
        vm.stopPrank();

        // ===== Simulate time between 9 and 12 months =====
        vm.warp(block.timestamp + 300 days);

        // ===== Setup: liquidator tries to liquidate =====
        address liquidator = address(0x999);
        stableToken.transfer(liquidator, borrowAmount - repaidAmount);
        vm.startPrank(liquidator);
        stableToken.approve(address(protocol), borrowAmount - repaidAmount);

        // ===== Expect revert: borrower has repaid 50% between 9 and 12 months =====
        vm.expectRevert(bytes("15")); // Adjust this error code based on your implementation
        protocol.liquidate(borrower);
        vm.stopPrank();
    }

}
