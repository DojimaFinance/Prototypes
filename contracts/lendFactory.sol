// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import './lend.sol';
import './lendNFT.sol';


contract lendFactory {

    address public tresaury; /// address that receives fees
    uint256 loanCounter = 0;

    uint256 fee;
    mapping(uint256 => address) public loans;
    mapping(address => address[]) public ownersLoans; 

    event loanCreated(address loanAddress, address _borrower, address _lender, address _collateral, address _debt, uint256 _collatAmt, uint256 _amtBorrowed);

    constructor(address _tresaury, uint256 _fee) public {
        tresaury = _tresaury;
        fee = _fee;
    }

    /// this will create a p2p loan with given erc20 locked as collateral and terms for what creator wants to borrow / how much / expiry of loan / interest rate etc
    function createLoan(address _collateral, address _debt, 
    uint256 _collatAmt, uint256 _amtBorrowed, uint256 _amtOwed, uint256 _timeToRepay, 
    bool _partialRepay, uint256 _interestRate) external returns (address loan) {
        IERC20 token = IERC20(_collateral);
        token.transferFrom(msg.sender, address(this), _collatAmt);        
        simpleLend loan = new simpleLend(_collateral, _debt, _collatAmt, _amtBorrowed, _amtOwed, _timeToRepay, _partialRepay, fee, _interestRate, tresaury);
        
        
        token.approve(address(loan), _collatAmt);
        loan.depositCollateral();
        loan.transferBorrower(msg.sender);
        //emit loanCreated(address(loans[loanCounter]), _borrower,  _lender,  _collateral,  _debt,  _collatAmt,  _amtBorrowed);
        loanCounter = loanCounter + 1;
        loans[loanCounter] = address(loan);
        address[] storage ownerLoansArray = ownersLoans[msg.sender];
        ownerLoansArray.push(address(loan));
        ownersLoans[msg.sender] = ownerLoansArray;
    }


    function getLoanAddress(uint256 loanNumber) public view returns (address) {
        // fails if the position has not been created
        require(address(loans[loanNumber]) != address(0));
        return address(loans[loanNumber]);
    }


}