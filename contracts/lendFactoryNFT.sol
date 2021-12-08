// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import './lend.sol';
import './lendNFT.sol';


contract lendFactoryNFT {

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


    function createLoanNFT(address _nftAddress, uint256 _tokenId, address _debt, 
    uint256 _amtBorrowed, uint256 _amtOwed, uint256 _timeToRepay, 
    uint256 _fee, uint256 _interestRate, address _dao, bool _partialRepay) external returns(address loan) {

        IERC721 collateralToken = IERC721(_nftAddress);
        simpleLendNFT loan = new simpleLendNFT(_nftAddress, _tokenId, _debt, _amtBorrowed, _amtOwed, _timeToRepay, fee, _interestRate, tresaury, _partialRepay);
        collateralToken.transferFrom(msg.sender, address(this), _tokenId);  
        collateralToken.approve(address(loan), _tokenId);
        loan.depositCollateral();
        loan.transferBorrower(msg.sender);

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