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
import "../interfaces/IERC3156FlashBorrower.sol";
import "../interfaces/IERC3156FlashLender.sol";

//import "./base.sol";


interface Option {
    function excerciseOptionPartial(uint256 _amt, address _recipient) external returns(uint256);
    function redeemDebt() external;
    function depositCollateral() external;
    function setBuyer(address _buyer) external;
    function setSeller(address _seller) external;
    function buyerAddress() external view returns(address);
    function seller() external view returns(address);
    function base() external view returns(IERC20);
    function short() external view returns(IERC20);
    function collatAmt() external view returns(uint256);
    function amtOwed() external view returns(uint256);
    function redeemAmt() external view returns(uint256);    
    function expired() external view returns(bool);
}

interface optionLong {
    function mintBuyerTokens() external;
    function excerciseOptions(uint256 _amount) external;
    function excerciseAll() external;
}

interface Comptroller {
    function isMarketListed(address cTokenAddress) external view returns (bool);
}

contract buyerERC20 is ERC20, ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    uint256 constant decimalAdj = 10000;
    address option; 
    uint256 amtOwed;
    uint256 minExecute;
    IERC20 public collatToken;
    IERC20 public debtToken;
    uint256 redeemAmt;
    uint256 collatAmt;
    uint256 public amtMinted;
    address public comptroller;
    IERC3156FlashLender lender;
    address weth;

    constructor (
        string memory _name, 
        string memory _symbol,
        address _option,
        uint256 _minExecute) public ERC20(_name, _symbol) {
        option = _option;
        collatToken = Option(option).base();
        debtToken = Option(option).short();
        collatAmt = Option(option).collatAmt(); 
        amtOwed = Option(option).amtOwed();
        require(_minExecute <= amtOwed);        
        amtMinted = 0;
        minExecute = _minExecute;
    }

    modifier onlyOption() {
        require(msg.sender == option);
        _;
    } 

    function mintBuyerTokens() external onlyOwner {
        require(amtMinted == 0);
        require(Option(option).buyerAddress() == address(this));
        _mint(msg.sender, amtOwed);
        debtToken.approve(option, amtOwed);
        amtMinted = amtOwed;
    }

    function excerciseOptions(uint256 _amount) public nonReentrant {
        require(_amount > minExecute);
        uint256 ibalance = balanceOf(msg.sender);
        require(_amount <= ibalance);
        debtToken.transferFrom(msg.sender, option, _amount);        
        redeemAmt = Option(option).excerciseOptionPartial(_amount, msg.sender);
        //collatToken.transfer(msg.sender, redeemAmt);
        _burn(msg.sender, _amount);
    }

    function excerciseOptionsAmm(uint256 _amount, address _router) public nonReentrant {
        require(_amount > minExecute);
        uint256 ibalance = balanceOf(msg.sender);
        require(_amount <= ibalance);
        redeemAmt = Option(option).excerciseOptionPartial(_amount, address(this));
        address[] memory path = getTokenOutPath(address(collatToken), address(debtToken));
        collatToken.approve(_router, redeemAmt);
        IUniswapV2Router01(_router).swapTokensForExactTokens(_amount, redeemAmt, path, address(this), now);
        debtToken.transfer(option, _amount);
        uint256 remainingBal = collatToken.balanceOf(address(this));
        collatToken.transfer(msg.sender, remainingBal);
        _burn(msg.sender, _amount);
    }


    function getTokenOutPath(address _token_in, address _token_out)
        internal
        view
        returns (address[] memory _path)
    {
        bool is_weth =
            _token_in == address(weth) || _token_out == address(weth);
        _path = new address[](is_weth ? 2 : 3);
        _path[0] = _token_in;
        if (is_weth) {
            _path[1] = _token_out;
        } else {
            _path[1] = address(weth);
            _path[2] = _token_out;
        }
    }



    function excerciseAll() public {
        uint256 ibalance = balanceOf(msg.sender);
        excerciseOptions(ibalance);
    }

}
