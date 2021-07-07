// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;

import "./token/ERC20.sol";
import "./token/ERC20Detailed.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */
contract Token is ERC20, ERC20Detailed {
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) public ERC20Detailed(_name, _symbol, _decimals) {
        _mint(msg.sender, _totalSupply * (10**uint256(decimals())));
    }
}
