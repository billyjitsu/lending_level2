// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/*
 Fun little borrow lend by @billyjitsu
*/

error InsufficientBalance(uint256 available, uint256 required);
error ExceedsMaximumBorrowLimit(uint256 maxAllowed, uint256 requested);
error Overpayment(uint256 available, uint256 requested);
error ContractUnderFunded(uint256 available, uint256 required);
error OverLeveraged(uint256 maxAllowed, uint256 requested);

contract BorrowLend {
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public borrows;

    constructor(){}

    function deposit() external payable {
        // Just a plain deposit
        deposits[msg.sender] += msg.value;
    }

    function borrow(uint256 _amount) external {
        // Calculate the maximum amount that can still be borrowed
        uint256 alreadyBorrowed = borrows[msg.sender];
        uint256 maxBorrowAmount = (deposits[msg.sender] * 70 / 100) - alreadyBorrowed;

        if (address(this).balance < _amount) {
            revert ContractUnderFunded({available: address(this).balance, required: _amount});
        }

        if (_amount > maxBorrowAmount) {
            revert ExceedsMaximumBorrowLimit({maxAllowed: maxBorrowAmount, requested: _amount});
        }
        //update balance before transfer
        borrows[msg.sender] += _amount;
        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function repay() external payable {
        // Don't allow overpayment
        if (msg.value > borrows[msg.sender]) {
            revert Overpayment({available: borrows[msg.sender], requested: msg.value});
        }
        borrows[msg.sender] -= msg.value;
    }

    function withdraw(uint256 withdrawAmount) public {
        // Calculate the maximum amount that can be withdrawn
        uint256 maxWithdrawalAmount = calculateMaxWithdrawalAmount(msg.sender);

        // Ensure the withdrawal amount does not exceed the maximum allowed
        if (withdrawAmount > maxWithdrawalAmount) {
            revert OverLeveraged({maxAllowed: maxWithdrawalAmount, requested: withdrawAmount});
        }

        if (withdrawAmount > address(this).balance) {
            revert InsufficientBalance({available: address(this).balance, required: withdrawAmount});
        }

        // Update the deposit record after withdrawal
        deposits[msg.sender] -= withdrawAmount;

        // Transfer the amount
        (bool success,) = msg.sender.call{value: withdrawAmount}("");
        require(success, "Transfer failed.");
    }

    function calculateMaxWithdrawalAmount(address _user) public view returns (uint256) {
        uint256 currentDeposit = deposits[_user];
        uint256 currentBorrow = borrows[_user];

        // Calculate the minimum deposit required to keep the borrow amount within 70% of the deposit
        uint256 requiredDepositAfterWithdraw = currentBorrow * 100 / 70;

        // Calculate the maximum amount that can be withdrawn
        uint256 maxWithdrawalAmount =
            currentDeposit > requiredDepositAfterWithdraw ? currentDeposit - requiredDepositAfterWithdraw : 0;

        return maxWithdrawalAmount;
    }

    // view total amount of ETH in contract for testing
    function getTotalContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
