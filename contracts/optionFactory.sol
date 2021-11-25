// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

//import "../interfaces/options.sol";
import "../interfaces/vaults.sol";
import './optionVaultSimple.sol';

interface optionVault {
    function setVaultUsage(address _vault, bool _useVault) external;
    function issueOptionsNew(uint256 _amtOwed, uint256 _collatAmt, uint256 _amtRaised, uint256 _saleTime) external;
    function transferOwnership(address _owner) external;
    function buyerAddress() external returns(address);
}


contract optionFactory {

    //address public feeToSetter;
    address public saleContract;
    uint256 public optionCounter = 0;
    address public optionIssued;
    mapping(uint256 => address) options;
    mapping(uint256 => address) buyers;
    mapping(uint256 => address) sellers;
    mapping(address => address[]) public ownersOptions; 

    event optionCreated(address loanAddress, address _buyer, address _seller, address _collateral, address _debt, uint256 _collatAmt, uint256 _amtOwed);

    constructor(address _saleContract) public {
        saleContract = _saleContract;
    }

    /// this will lock funds in escrow while creating option with an ERC20 token representing right to exercise options which is sold through Sales Contract
    /// holder of the buyerERC20 token can excercise options at any time prior to the options expiry 
    function createOption(
        address _collateral, 
        address _debt, 
        uint256 _collatAmt, 
        uint256 _amtOwed, 
        uint256 _minExcercise,
        uint256 _optionSalePrice,
        uint256 _saleTime,
        uint256 _expirytime, 
        uint256 _timeBeforeDeadline
    ) external returns (uint256 opt) {
        optionCounter = optionCounter + 1;

        address optVault;
        address buyer;
        {
            IERC20 token = IERC20(_collateral);
            optionVaultSimple opt = new optionVaultSimple(_collateral, _debt, _minExcercise, saleContract, _expirytime, _timeBeforeDeadline);
            optionIssued = address(opt);
            /*
            if (_useVault){
                opt.setVaultUsage(_vault, _useVault);

            }
            */
            token.transferFrom(msg.sender, address(opt), _collatAmt);   
        }
        {     
            optionVault(optionIssued).issueOptionsNew(_amtOwed, _collatAmt, _optionSalePrice, _saleTime);
            optionVault(optionIssued).transferOwnership(msg.sender);
            buyer = optionVault(optionIssued).buyerAddress();
        }
        IERC20 buyerToken = IERC20(buyer);
        uint256 _amtSold = buyerToken.balanceOf(address(this));
        {
            options[optionCounter] = optionIssued;
        }

        address[] storage ownerOptionsArray = ownersOptions[msg.sender];
        ownerOptionsArray.push(address(options[optionCounter]));
        ownersOptions[msg.sender] = ownerOptionsArray;

        //emit optionCreated(options[optionCounter], buyers[optionCounter],  sellers[optionCounter],  _collateral,  _debt,  _collatAmt,  _amtOwed);
        return(optionCounter);

    }

    function getOptionsAddress(uint256 opt) public view returns (address) {
        // fails if the position has not been created
        require(options[opt] != address(0));
        return (options[opt]);
    }

    function getBuyerAddress(uint256 opt) public view returns (address) {
        // fails if the position has not been created
        require(options[opt] != address(0));
        return buyers[opt];
    }

    function getSellerAddress(uint256 opt) public view returns (address) {
        // fails if the position has not been created
        require(options[opt] != address(0));
        return (sellers[opt]);
    }

}