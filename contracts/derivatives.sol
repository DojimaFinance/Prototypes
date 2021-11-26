// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/uniswap.sol";
import "../interfaces/vaults.sol";
import "./base.sol";


contract option is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    uint256 constant decimalAdj = 10000;
    uint256 constant vaultDecimalAdj = 10000;

    bool collateralProvided;
    bool isRepaid;
    bool buyerRightsOnSale;
    bool sellerRightsOnSale;
    uint256 public deadline; 
    uint256 public collatAmt;
    uint256 public amtOwed; 
    uint256 public timeToExcercise; 
    uint256 public mintDeadline; 

    IERC20 public collateralToken;
    IERC20 public debtToken; 
    address public buyer;
    address public seller; 
    //address public owner;
    bool public useVault;
    address public vaultAddress;

    /*
    Simple option contract that can act as call / put option 
    owner creates contract by depositing collateral 
    owner can then sell rights to buyer who can swap debt token for collateral at some pre set value
    owner can sell rights to seller who either receives debt token when option excercised or can 

    buyer = right to excercise option
    seller = can redeem at expiry or receives debt tokens if lender excercises option
    */

    constructor(
        address _collateral, 
        address _debt, 
        uint256 _collatAmt, 
        uint256 _amtOwed, 
        uint256 _timeToMint,
        uint256 _timeToRepay, 
        address _vault, 
        bool _useVault ) public {
        //owner = _owner;
        collateralToken = IERC20(_collateral);
        debtToken = IERC20(_debt); 
        collatAmt = _collatAmt; 
        amtOwed = _amtOwed; 
        timeToExcercise = _timeToRepay;
        mintDeadline = block.timestamp + _timeToMint;
        collateralProvided = false;
        isRepaid = false; 
        useVault = _useVault;
        vaultAddress = _vault;
        if (useVault == true){
            collateralToken.approve(vaultAddress,collatAmt);
        }
    }

    function setBuyer(address _buyer) external {
        require(msg.sender == owner());
        buyer = _buyer;
    }

    function setSeller(address _seller) external {
        require(msg.sender == owner());
        seller = _seller;
    }


    function expired() public returns(bool){
        require(collateralProvided == true); 
        return(block.timestamp > deadline);
    }

    function depositCollateral() external {
        require(collateralProvided == false); 
        //require(msg.sender == owner()); 
        collateralToken.transferFrom(msg.sender, address(this), collatAmt);
        collateralProvided = true; 
        buyer = owner(); 
        seller = owner(); 
        deadline = block.timestamp + timeToExcercise; 
        if (useVault == true){
            vault(vaultAddress).deposit(collatAmt);
        }
    }
    
    function withdrawAmount(uint256 _amount) internal {
        uint256 withdrawAmt = _amount.mul(vaultDecimalAdj).div(vault(vaultAddress).pricePerShare());
        vault(vaultAddress).withdraw(); /// to do fix 
    }
    
    function vaultBalance() internal view returns(uint256) {
        uint256 bal = vault(vaultAddress).balanceOf(address(this));
        return(bal);
        
    }
    
    function excerciseOption() external {
        require(msg.sender == buyer); 
        require(collateralProvided == true);
        require(block.timestamp <= deadline);
        debtToken.transferFrom(msg.sender, address(seller), amtOwed);
        if (useVault == true){
            vault(vaultAddress).withdraw();
        }
        collateralToken.transferFrom(address(this), address(buyer), collatAmt);
        isRepaid = true;
    }

    function excerciseOptionPartial(uint256 _amt, address _recipient) external returns(uint256) {
        require(msg.sender == buyer); 
        require(_amt <= amtOwed);
        require(collateralProvided == true);
        require(block.timestamp <= deadline);
        uint256 percentRepaid = _amt.mul(decimalAdj).div(amtOwed);
        debtToken.transferFrom(buyer, address(seller), _amt);
        uint256 redeemAmt = collatAmt.mul(percentRepaid).div(decimalAdj);
        if (useVault == true){
            withdrawAmount(_amt);
        }
        collateralToken.transfer(_recipient, redeemAmt);

        amtOwed = amtOwed.sub(_amt);
        collatAmt = collatAmt.sub(redeemAmt);
        return(redeemAmt);
    }

    function redeemDebt() external {
        require(msg.sender == seller); 
        require(collateralProvided == true);
        require(isRepaid == false); 
        require(block.timestamp > deadline);
        amtOwed = 0; 
        collateralToken.transferFrom(address(this), address(seller), collatAmt);
        isRepaid = true;
    }

    function redeemDebtEarly() external {
        require(msg.sender == seller); 
        require(msg.sender == buyer); 

        require(collateralProvided == true);
        require(isRepaid == false); 
        amtOwed = 0; 
        collateralToken.transferFrom(address(this), address(seller), collatAmt);
        isRepaid = true;
    }

}
