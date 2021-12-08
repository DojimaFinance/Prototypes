// SPDX-License-Identifier: MIT
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
import "./base.sol";

interface lender {
    function depositCollateral() external;
    function redeemCollateralNoDebt() external;
    function provideDebt() external;
    function repayDebt() external;
    function redeemCollateral() external;
    function liquidiateLender() external;
}

contract simpleLend is derivate {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    address public factory;
    bool partialRepay;

    function transferLender(address _lender) external {
        require(msg.sender == lender);
        lender = _lender;

    }

    function transferBorrower(address _borrower) external {
        require(msg.sender == borrower);
        borrower = _borrower; 
    }


    constructor (address _collateral, address _debt, 
    uint256 _collatAmt, uint256 _amtBorrowed, uint256 _amtOwed, uint256 _timeToRepay, bool _partialRepay,
    uint256 _fee, uint256 _interestRate, address _dao ) public {
        factory = msg.sender;
        //borrower = _borrower;
        //lender = _lender;
        collateralToken = IERC20(_collateral);
        debtToken = IERC20(_debt); 
        collatAmt = _collatAmt; 
        amtBorrowed = _amtBorrowed;
        amtOwed = _amtOwed; 
        timeToRepay = _timeToRepay;
        lenderLiquidate = false;
        borrowLiquidate = false; 
        partialRepay = _partialRepay;
        fee = _fee;
        dao = _dao;
        interestRate = _interestRate;

    }


    function repayPartialDebt(uint256 amt) external {
        amtOwed = getAmountOwed();
        interestCounter = block.timestamp;
        require(amt < amtOwed);
        require(debtProvided == true);
        require(partialRepay == true);
        require(block.timestamp <= deadline);
        debtToken.transferFrom(msg.sender, address(lender), amt);
        uint256 percentRepaid = amt.mul(decimalAdj).div(amtOwed);
        uint256 collatRedeemed = collatAmt.mul(percentRepaid).div(decimalAdj);
        collateralToken.transferFrom(address(this), address(borrower), collatRedeemed);        
        collatAmt = collatAmt.sub(collatRedeemed);
        amtOwed = amtOwed.sub(amt);
    }
}

