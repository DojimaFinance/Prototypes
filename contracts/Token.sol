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
/**
    @title Bare-bones Token implementation
    @notice Based on the ERC-20 token standard as defined at
            https://eips.ethereum.org/EIPS/eip-20
 */
contract Token is ERC20, Ownable {

    using SafeMath for uint256;

    constructor(string memory _name, string memory _ticker) ERC20(_name, _ticker) public
    {

    }

    uint256 constant private _maxTotalSupply = 10000000e18; // 10,000,000 max 

    function mint(address _to) public onlyOwner {
        require(totalSupply() == 0, "ERC20: minting more then MaxTotalSupply");

        _mint(_to, _maxTotalSupply);
    }


}
