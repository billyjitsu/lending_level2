// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {BorrowLend} from "../src/Borrow.sol";

contract BorrowTest is Test {
    BorrowLend public borrowLend;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        borrowLend = new BorrowLend();

        vm.deal(alice, 10000);
        vm.deal(bob, 10000);
    }

    function test_Deposit() public {
        vm.startPrank(msg.sender);
        borrowLend.deposit{value: 1000}();
        assertEq(borrowLend.deposits(msg.sender), 1000);
        vm.stopPrank();
        vm.startPrank(alice);
        borrowLend.deposit{value: 5000}();
        assertEq(borrowLend.deposits(alice), 5000);
        vm.stopPrank();
        // console2.log("deposits: ", borrowLend.getTotalContractBalance());
    }

    function testFuzz_Deposit(uint8 x) public {
        vm.startPrank(msg.sender);
        borrowLend.deposit{value: x}();
        assertEq(borrowLend.deposits(msg.sender), x);
        vm.stopPrank();
    }

    function test_Borrow() public {
        vm.startPrank(alice);
        borrowLend.deposit{value: 1000}();
        vm.stopPrank();
        // Try to borrow with no deposit
        vm.startPrank(bob);
        vm.expectRevert();
        borrowLend.borrow(500);
        vm.stopPrank();
        // Try to borrow more than 70% of deposit
        vm.startPrank(alice);
        vm.expectRevert();
        borrowLend.borrow(800);
        // Try to borrow 70% of deposit
        borrowLend.borrow(700);
        // Try to borrow just a little more
        vm.expectRevert();
        borrowLend.borrow(1);
        vm.stopPrank();
        // console2.log("deposits: ", borrowLend.getTotalContractBalance());
        // console2.log("deposits: ", borrowLend.deposits(alice));
        // console2.log("borrows: ", borrowLend.borrows(alice));
    }

    function test_Repay() public {
        vm.startPrank(alice);
        borrowLend.deposit{value: 1000}();
        // Borrow 70% of deposit
        borrowLend.borrow(700);

        // Try to repay more than borrowed
        vm.expectRevert();
        borrowLend.repay{value: 701}();
        // Repay less than borrowed
        borrowLend.repay{value: 50}();
        assertEq(borrowLend.borrows(alice), 650);

        // Try to borrow more than 70% of deposit
        vm.expectRevert();
        borrowLend.borrow(51);
        // Repay borrowed amount
        borrowLend.repay{value: 650}();
        // console2.log("deposits: ", borrowLend.deposits(alice));
        // console2.log("borrows: ", borrowLend.borrows(alice));

        // Deposit more to borrow even more
        borrowLend.deposit{value: 1000}();
        borrowLend.borrow(1400);
        // try to borrow over
        vm.expectRevert();
        borrowLend.borrow(1);

        // Repay borrowed amount
        borrowLend.repay{value: 1400}();

        vm.stopPrank();
        // console2.log("deposits: ", borrowLend.deposits(alice));
        // console2.log("borrows: ", borrowLend.borrows(alice));
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        borrowLend.deposit{value: 1000}();
        vm.stopPrank();

        // Try to withdraw with no deposit
        vm.startPrank(bob);
        vm.expectRevert();
        borrowLend.withdraw(100);
        vm.stopPrank();

        vm.startPrank(alice);
        // Borrow 70% of deposit
        borrowLend.borrow(500);
        uint256 maxWithdraw = borrowLend.calculateMaxWithdrawalAmount(alice);
        // console2.log("maxWithdraw: ", maxWithdraw);

        // Try to withdraw more than 70% of deposit
        vm.expectRevert();
        borrowLend.withdraw(maxWithdraw + 1);
        // Withdraw 70% of deposit
        borrowLend.withdraw(maxWithdraw);

        // Repay borrowed amount
        borrowLend.repay{value: 500}();

        maxWithdraw = borrowLend.calculateMaxWithdrawalAmount(alice);
        // console2.log("maxWithdraw: ", maxWithdraw);

        // console2.log("deposits: ", borrowLend.deposits(alice));
        // console2.log("borrows: ", borrowLend.borrows(alice));

        // Withdraw balance with no borrow
        borrowLend.withdraw(maxWithdraw);
        vm.stopPrank();
    }
}
