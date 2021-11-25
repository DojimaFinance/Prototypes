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
import "../interfaces/options.sol";
import "../interfaces/vaults.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

struct saleInformation{


    address saleToken;
    address buyToken;
    address treasury;
    address saleOwner; 
    uint256 amountOffered; 
    uint256 purchaseAmount; 
    uint256 minPurhcase;
    uint256 maxPurchase;
    uint256 saleTime;
    uint256 openingTime; 
    uint256 totalSold; 
}

contract saleContract is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    uint256 constant BPS_Adj = 10000;
    uint256 public fee;
    address public feeTo; /// address that receives proceeds 
    uint256 public saleNumber; /// tracking the sale number 
    mapping(uint256 => saleInformation) public sales; 

    constructor (uint256 _fee) public {
        saleNumber = 0;
        require(_fee <= 250); // fee cannot be higher than 2.5%
        fee = _fee;
        
    }

    function newSale(
        address _saleToken,
        address _buyToken,
        address _treasury,
        address _saleOwner,
        uint256 _amountOffered, 
        uint256 _purchaseAmount, 
        uint256 _minPurhcase,
        uint256 _maxPurchase,
        uint256 _saleTime        
    ) external returns (uint256) {
        saleNumber = saleNumber.add(1);
        saleInformation memory sale = saleInformation(
            _saleToken,
            _buyToken,
            _treasury,
            _saleOwner,
            _amountOffered, 
            _purchaseAmount, 
            _minPurhcase,
            _maxPurchase,
            _saleTime,   
            block.timestamp,
            uint256(0)
        );
        sales[saleNumber] = sale;
        IERC20 saleToken = IERC20(sale.saleToken);
        saleToken.transferFrom(msg.sender, address(this), _amountOffered);
        return(saleNumber);

    }

    function saleActive(uint256 _saleNumber) public view returns(bool)  { 
        saleInformation storage sale = sales[_saleNumber];
        if ( block.timestamp <= (sale.openingTime).add(sale.saleTime)) return true;
        if ( block.timestamp > (sale.openingTime).add(sale.saleTime)) return false;
    }


    function purchaseTokens(uint256 _saleNumber, uint256 _amount) public nonReentrant {
        saleInformation storage sale = sales[_saleNumber];
        require(saleActive(_saleNumber), "Sale Not Active");
        require(_amount >= sale.minPurhcase && _amount <= sale.maxPurchase, "Sale Not within min max threshold");
        //require(_amount >= (sale.amountOffered).sub(sale.totalSold), "Not enough tokens left" );
        uint256 price = _amount.mul(sale.purchaseAmount).div(sale.amountOffered);
        uint256 feePaid = price.mul(fee).div(BPS_Adj);
        IERC20 buyToken = IERC20(sale.buyToken);
        IERC20 saleToken = IERC20(sale.saleToken);
        saleToken.transfer(msg.sender, _amount);
        buyToken.transferFrom(msg.sender, sale.treasury, price.sub(feePaid));
        buyToken.transferFrom(msg.sender, owner(), feePaid);

        sale.totalSold = (sale.totalSold).add(_amount);
        sales[saleNumber] = sale;
    }

    function amountRemaining(uint _saleNumber) public view returns(uint256) {
        saleInformation storage sale = sales[_saleNumber];
        return((sale.amountOffered).sub(sale.totalSold));
    }


    function redeemUnpurchased(uint256 _saleNumber) public {
        saleInformation storage sale = sales[_saleNumber];
        require(sale.saleOwner == msg.sender);
        require(saleActive(_saleNumber) == false, "Sale Still Active");
        require((sale.amountOffered).sub(sale.totalSold) > 0, "Not enough tokens left" );
        uint256 unsold = (sale.amountOffered).sub(sale.totalSold);
        IERC20 saleToken = IERC20(sale.saleToken);
        saleToken.transfer(sale.treasury, unsold);
        sales[saleNumber] = sale;
    }

    
    function getSaleTokens(uint256 _saleNumber) public view returns(address) {
        saleInformation storage sale = sales[_saleNumber];
        return( sale.saleToken);

    }

    function getBuyTokens(uint256 _saleNumber) public view returns(address) {
        saleInformation storage sale = sales[_saleNumber];
        return( sale.buyToken);
    }   

    function getAmountOffered(uint256 _saleNumber) public view returns(uint256) {
        saleInformation storage sale = sales[_saleNumber];
        return( sale.amountOffered);
    }   

    function getPurchaseAmount(uint256 _saleNumber) public view returns(uint256) {
        saleInformation storage sale = sales[_saleNumber];
        return( sale.purchaseAmount);
    }   

    function getTotalSold(uint256 _saleNumber) public view returns(uint256) {
        saleInformation storage sale = sales[_saleNumber];
        return( sale.totalSold);
    }   

    function getTimeRemaining(uint256 _saleNumber) public view returns(uint256) {
        saleInformation storage sale = sales[_saleNumber];
        require(saleActive( _saleNumber) == true, "Sale Not Active");
        return((sale.openingTime).add(sale.saleTime).sub(block.timestamp));
    }   


}