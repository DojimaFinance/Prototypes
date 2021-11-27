// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import './derivatives.sol';
import './derivativePool.sol';
//import './optionFactory.sol';
//import './screampriceoracle.sol';
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


interface saleInterface {
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
    ) external returns(uint256);

    function redeemUnpurchased(uint256 _saleNumber) external;
}

/// this contract holds funds in escrow until option expires allowing buyer to excercise by swapping short for base at pre-agreed exchange rate (amtOwed / collatAmt)
/// owner also has option to deploy collateral to a vault to earn yield while still being locked + also can re-issue new options once currently issued options have expired
contract optionVaultSimple is Ownable {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    IERC20 public base;
    IERC20 public short;
    bool public collateralProvided;
    uint256 constant BPS_adj = 10000;
    uint256 public minSale;
    address public vaultAddress = address(0);
    address public buyerAddress;
    uint256 public minExcercise;
    address public salesContract;
    uint256 public deadline;
    uint256 public earlyExecute;

    uint256 public collatAmt;
    uint256 public amtOwed;

    bool public useVault = false;
    bool public optionsIssued = false;
    uint256 public mintTime = 3600; // on hour 
    uint256 public expiryTime; // time between option issued and when can be executed
    uint256 public timeBeforeDeadline; // time before expiry option can be executed i.e. may want to limit to last 24hs

    uint256 public auctionTime = 43200; // 12 hours in seconds
    uint256 public optionCounter;
    optionLong public buyer;


    constructor(
        address _base,
        address _short,
        uint256 _minExcercise,
        address _salesContract,
        uint256 _expiryTime,
        uint256 _timeBeforeDeadline



    ) public {
        base = IERC20(_base);
        short = IERC20(_short);
        minExcercise = _minExcercise;
        salesContract = _salesContract;
        expiryTime = _expiryTime;
        timeBeforeDeadline = _timeBeforeDeadline;
    }

    // set pricing paramaters for options 
    // _premium = premium of strike price vs oracle price 
    //  _minSale is used to determine floor price when options are auctioned


    // adjust vault paramaters i.e. if vaults are used within option to earn yield on funds locked in escrow by option
    function setVaultUsage(address _vault, bool _useVault) external onlyOwner {
        vaultAddress = _vault;
        useVault = _useVault;
        base.approve(vaultAddress, uint(-1));
    }

    /// withdraws base token from vault -> used when option excercised 
    function withdrawAmount(uint256 _amount) internal {
        uint256 vaultBPS = 1000000000000000000; /// TO DO UPDATE THIS TO READ FROM VAULT 
        uint256 withdrawAmt = _amount.mul(vaultBPS).div(vault(vaultAddress).pricePerShare());
        vault(vaultAddress).withdraw();
    }

    // Adjust timing of options (time to deposit collateral & expiry time from when collateral is deposited)
    function setOptionTiming(uint256 _mintTime, uint256 _expiryTime, uint256 _auctionTime) external onlyOwner {
        mintTime = _mintTime;
        expiryTime = _expiryTime;
        auctionTime = _auctionTime;
    }

    /// to check that funds are enough to create options and lock in escrow 
    function balanceBase() public view returns(uint256) {
        uint256 bal = base.balanceOf(address(this));
        if (useVault == true ){
            IERC20 vaultToken = IERC20(vaultAddress);
            uint256 vaultBPS = 1000000000000000000; /// TO DO UPDATE THIS TO READ FROM VAULT 
            uint256 vaultBalance = vaultToken.balanceOf(address(this)).mul(vault(vaultAddress).pricePerShare()).div(vaultBPS);

            bal = bal.add(vaultBalance);
        }
        return(bal);
    }

    function balanceDebt() public view returns(uint256) {
        uint256 bal = short.balanceOf(address(this));
        return(bal);
    }



    // Issues new options with collateral held in Vault 
    function issueOptions(uint256 _amtOwed, uint256 _collatAmt, uint256 _amtRaised, uint256 _saleTime) internal {
        collatAmt = _collatAmt;
        amtOwed = _amtOwed;
        
        require(balanceBase() >= collatAmt);
        if (optionsIssued == true){
            require(expired() == true);
        }
        //collateralProvided = true;
        require(timeBeforeDeadline <= expiryTime, "Must be some time for holders to execute options");
        deadline = (block.timestamp).add(expiryTime);
        earlyExecute = deadline.sub(timeBeforeDeadline);

        buyerERC20 NewBuyer = new buyerERC20("OptionTEST", "OPT", address(this), minExcercise);
        buyerAddress = address(NewBuyer);
        NewBuyer.mintBuyerTokens();
        IERC20 buyerToken = IERC20(buyerAddress);
        buyer = optionLong(buyerAddress);
        optionsIssued = true;
        collateralProvided = true;
        buyerToken.approve(salesContract, _amtOwed);
        launchSale(buyerAddress, address(base), buyerToken.totalSupply(),  _amtRaised, 0, buyerToken.totalSupply(), _saleTime);
        

    }
    // checks if current issued option is expired 
    function expired() public returns(bool){
        require(collateralProvided == true); 
        return(block.timestamp > deadline);
    }

    function vaultBalance() internal view returns(uint256) {
        uint256 bal = vault(vaultAddress).balanceOf(address(this));
        return(bal);
    }

    function depositToVault() external onlyOwner {
        uint256 bal = base.balanceOf(address(this));
        vault(vaultAddress).deposit(bal);
    }

    function withdrawFromVault() external onlyOwner {
        vault(vaultAddress).withdraw();
    }

    // Issue new options with collateral held in Vault 
    function issueOptionsNew(uint256 _amtOwed, uint256 _collatAmt, uint256 _amtRaised, uint256 _saleTime) external  {
        
        if (optionsIssued == true){
            require (expired() == true);
            ///optionInt.redeemDebt();

        }

        if (balanceBase() < collatAmt){
            base.transferFrom(owner(), address(this), collatAmt.sub(base.balanceOf(address(this))));
        }
        
        issueOptions(_amtOwed, _collatAmt, _amtRaised, _saleTime);
    }

    function excerciseOption() external {
        require(msg.sender == address(buyer)); 
        require(collateralProvided == true);
        //require(block.timestamp >= earlyExecute);
        require(block.timestamp <= deadline);
        short.transferFrom(msg.sender, address(this), amtOwed);
        if (useVault == true){
            vault(vaultAddress).withdraw();
        }
        base.transferFrom(address(this), address(buyer), collatAmt);
        //isRepaid = true;
    }

    function excerciseOptionPartial(uint256 _amt, address _recipient) external returns(uint256) {
        require(msg.sender == address(buyer)); 
        require(_amt <= amtOwed);
        require(collateralProvided == true);
        //require(block.timestamp >= earlyExecute);
        require(block.timestamp <= deadline);
        uint256 percentRepaid = _amt.mul(BPS_adj).div(amtOwed);
        uint256 redeemAmt = collatAmt.mul(percentRepaid).div(BPS_adj);
        if (useVault == true){
            vault(vaultAddress).withdraw();
        }
        base.transfer(_recipient, redeemAmt);
        //short.transferFrom(msg.sender, address(this), _amt);

        if (useVault == true){
            uint256 bal = base.balanceOf(address(this));
            vault(vaultAddress).deposit(bal);
        }
        amtOwed = amtOwed.sub(_amt);
        collatAmt = collatAmt.sub(redeemAmt);
        return(redeemAmt);
    }

    // withdraw specific token 
    function withdrawFunds(address _token) external onlyOwner {
        require(expired() == true);
        IERC20 tokenWithdraw =  IERC20(_token);
        uint256 balance = tokenWithdraw.balanceOf(address(this));
        tokenWithdraw.transfer(owner(), balance);

    }

    function launchSale(address _buyer, address _debt, uint256 _amtSold, uint256 _amtRaise, uint256 _minSale, uint256 _maxSale, uint256 _saleTime) internal {
        saleInterface(salesContract).newSale(
            _buyer,
            _debt,
            address(this),
            address(this),
            _amtSold, 
            _amtRaise, 
            _minSale,
            _maxSale,
            _saleTime            
        );
    }


}