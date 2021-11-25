// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.0 <0.7.0;

import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface optionVault {
    function setOptionPricing(uint256 _premium, uint256 _minSale, uint256 _priceFloor) external;
    function setVaultUsage(address _vault, bool _useVault) external;
    function setOptionTiming(uint256 _mintTime, uint256 _expiryTime, uint256 _auctionTime) external;
    function issueOptionsNew(uint256 amtOwed, uint256 collatAmt) external; 
    function withdrawAndReissue(uint256 amtOwed, uint256 collatAmt) external;
    function withdrawExpiredOptions() external;
    function withdrawFunds(address _token) external;
    function base() external view returns(address);
    function short() external view returns(address);
    function buyerAddress() external view returns(address);
    function optionAddress() external view returns(address);
    function balanceBase() external view returns(uint256);
    function balanceDebt() external view returns(uint256);


}

interface optFactory {
    function createOption(
        address _owner, 
        address _collateral, 
        address _debt, 
        uint256 _collatAmt, 
        uint256 _amtOwed, 
        uint256 _timeToMint  ,
        uint256 _timeToRepay, 
        address _vault, 
        bool _useVault 
    ) external returns(uint256);


    function getOptionsAddress(uint256 opt) external view returns (address);
    function getBuyerAddress(uint256 opt) external view returns (address);
    function getSellerAddress(uint256 opt) external view returns (address);
    function optionCounter() external view returns(uint256);

}