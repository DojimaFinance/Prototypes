// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/uniswap.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract derivate is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
        
    bool public isRepaid = false;
    bool public collateralProvided = false;
    bool public debtProvided = false;
    bool public whitelistLender; 
    uint256 constant decimalAdj = 10000;
    address lender;
    address borrower; 
    address dao;    
    IERC20 public collateralToken;
    IERC20 public debtToken; 
    uint256 public timeToRepay;
    uint256 public deadline; 
    uint256 public collatAmt;
    uint256 public amtBorrowed; 
    uint256 public amtOwed; 
    uint256 public excerciseOptionAmt; 
    uint256 public fee;  
    uint256 public interestRate;
    uint256 public interestCounter;
    uint256 constant secondsPerYear = 31536000;
    bool lenderLiquidate;
    bool borrowLiquidate;


    function getAmountOwed() public view returns(uint256) {
        uint256 timeSinceLoan = (block.timestamp).sub(interestCounter);
        uint256 interest = amtOwed.mul(interestRate).mul(timeSinceLoan).div(decimalAdj).div(secondsPerYear);
        return(amtOwed.add(interest));

    }

    // borrower must first deposit collateral before borrowing
    function depositCollateral() external {
        require(collateralProvided == false); 
        //require(msg.sender == borrower); 
        collateralToken.transferFrom(msg.sender, address(this), collatAmt);
        collateralProvided = true; 
    }

    // borrower can redeem collateral if no borrower has provided debt 
    function redeemCollateralNoDebt() external {
        require(msg.sender == lender); 
        //require(collateralProvided == true);
        require(debtProvided == false);
        collateralToken.transferFrom(address(this), address(borrower), collatAmt);
        collateralProvided = false; 
        amtOwed = 0; 
        deadline = (block.timestamp).add(timeToRepay);
    }

    // lender provides debt to borrower + fee paid to owner 
    function provideDebt() external {
        require(debtProvided == false); 
        require(collateralProvided == true);
        interestCounter = block.timestamp;
        deadline = block.timestamp + timeToRepay;
        uint256 feePaid =  amtBorrowed.mul(fee).div(decimalAdj);
        debtToken.transferFrom(msg.sender, address(dao), feePaid);
        debtToken.transferFrom(msg.sender, address(borrower), amtBorrowed.sub(feePaid));
        debtProvided = true; 
        isRepaid = false;
        lender = msg.sender;
    }

    // debt get's repays debt (any one can repay the debt on behalf of the borrower)
    function repayDebt() external {
        //require(msg.sender == borrower); 
        require(debtProvided == true);
        require(block.timestamp <= deadline);
        debtToken.transferFrom(msg.sender, address(lender), getAmountOwed());
        amtOwed = 0; 
        collateralToken.transfer(address(borrower), collatAmt);
        isRepaid = true;
    }

    // lender can redeem collateral from contract if debt is unrepayed after deadline 
    function redeemCollateral() external {
        require(msg.sender == lender); 
        require(debtProvided == true);
        require(block.timestamp > deadline);
        require(isRepaid = false); 
        amtOwed = 0; 
        collateralToken.transferFrom(address(this), address(lender), collatAmt);
    }

    // borrower can liquidate a portion of collateral to repay debt & retain remaining collateral 
    function liquidiateBorrower(address router, uint256 amountInMax, address[] calldata path, uint256 ) external {
        require(msg.sender == borrower);
        require(debtProvided == true);
        require(isRepaid = false); 
        require(borrowLiquidate==true);
        IUniswapV2Router01(router).swapTokensForExactTokens(amtOwed, amountInMax, path, address(this), block.timestamp + 10);
        debtToken.transferFrom(address(this), address(lender), amtOwed);
        uint256 remainingBal = collateralToken.balanceOf(address(this));
        collateralToken.transferFrom(address(this), address(borrower), collatAmt);
    }

    // lender has option to take collateral & borrower no longer needs to repay the debt 
    function liquidiateLender() external {
        require(msg.sender == lender);
        require(debtProvided == true);
        require(isRepaid = false); 
        require(lenderLiquidate==true);
        collateralToken.transferFrom(address(this), address(lender), collatAmt);
        isRepaid = true;
        amtOwed = 0;
    }

}

