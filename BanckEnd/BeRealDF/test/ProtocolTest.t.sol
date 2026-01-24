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


}
