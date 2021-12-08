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
import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/uniswap.sol";


contract simpleLendNFT {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
        
    bool public isRepaid = false;
    bool public collateralProvided = false;
    bool public debtProvided = false;
    bool public whitelistLender; 
    uint256 constant secondsPerYear = 31536000;
    uint256 constant decimalAdj = 10000;
    address lender; 
    address borrower; 
    address dao = 0xa017adA64aF281ef6197F6FF341F6514fAa1E5A0;    

    uint256 tokenId;
    IERC721 collateralToken;
    IERC20 public debtToken; 
    uint256 public timeToRepay;
    uint256 deadline; 
    uint256 public amtBorrowed; 
    uint256 public amtOwed; 
    uint256 public excerciseOptionAmt; 
    uint256 public fee;
    uint256 public interestRate;
    uint256 public interestCounter;
    bool public partialRepay;


    function transferLender(address _lender) external {
        require(msg.sender == lender);
        lender = _lender;

    }

    function transferBorrower(address _borrower) external {
        require(msg.sender == borrower);
        borrower = _borrower; 
    }


    constructor(address _nftAddress, uint256 _tokenId, address _debt, 
    uint256 _amtBorrowed, uint256 _amtOwed, uint256 _timeToRepay, 
    uint256 _fee, uint256 _interestRate, address _dao, bool _partialRepay) public {
        //borrower = _borrower;
        collateralToken = IERC721(_nftAddress);
        debtToken = IERC20(_debt); 
        tokenId = _tokenId; 
        amtBorrowed = _amtBorrowed;
        amtOwed = _amtOwed; 
        timeToRepay = _timeToRepay;
        fee = _fee;
        interestRate = _interestRate;
        dao = _dao;
        partialRepay = _partialRepay;
    }

    function getAmountOwed() public view returns(uint256) {
        uint256 timeSinceLoan = (block.timestamp).sub(interestCounter);
        uint256 interest = amtOwed.mul(interestRate).mul(timeSinceLoan).div(decimalAdj).div(secondsPerYear);
        return(amtOwed.add(interest));

    }

    function depositCollateral() external  {
        require(collateralProvided == false); 
        collateralToken.transferFrom(msg.sender, address(this), tokenId);
        collateralProvided = true; 
        borrower = msg.sender;
    }

    // borrower can redeem collateral if no borrower has provided debt 
    function redeemCollateralNoDebt() external  {
        require(msg.sender == lender); 
        require(collateralProvided == true);
        require(debtProvided == false);
        collateralToken.transferFrom(address(this), address(borrower), tokenId);
        collateralProvided = false; 
        amtOwed = 0; 
    }

    // lender provides debt to borrower + fee paid to owner 
    function provideDebt() external {
        //require(msg.sender == lender); 
        require(collateralProvided == true);
        deadline = block.timestamp + timeToRepay;
        uint256 feePaid =  amtBorrowed.mul(fee).div(decimalAdj);
        debtToken.transferFrom(msg.sender, address(dao), feePaid);
        debtToken.transferFrom(msg.sender, address(borrower), amtBorrowed.sub(feePaid));
        lender = msg.sender;
        debtProvided = true; 
        isRepaid = false;
        interestCounter = block.timestamp;
    }

    // debt gets repayed (any one can repay the debt on behalf of the borrower)
    function repayDebt() external {
        //require(msg.sender == borrower); 
        require(debtProvided == true);
        require(block.timestamp <= deadline);
        debtToken.transferFrom(msg.sender, address(lender), getAmountOwed());
        amtOwed = 0; 
        collateralToken.transferFrom(address(this), address(borrower), tokenId);
        isRepaid = true;
    }

    function repayPartialDebt(uint256 amt) external {
        amtOwed = getAmountOwed();
        require(amt < amtOwed);
        require(debtProvided == true);
        require(partialRepay == true);
        require(block.timestamp <= deadline);
        debtToken.transferFrom(msg.sender, address(lender), amt);
        uint256 percentRepaid = amt.mul(decimalAdj).div(amtOwed);
        interestCounter = block.timestamp;        
        amtOwed = amtOwed.sub(amt);
    }

    // lender can redeem collateral from contract if debt is unrepayed after deadline 
    function redeemCollateral() external  {
        require(msg.sender == lender); 
        require(debtProvided == true);
        require(block.timestamp > deadline);
        require(isRepaid == false); 
        amtOwed = 0; 
        collateralToken.transferFrom(address(this), address(lender), tokenId);
    }


}

