// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Admin.sol";

contract Hen is HenAdmin {
    bool private initialized;

    function initialize(uint256 _dayRate, uint256 _yearRate, address _giveToken, uint256 _giveRate, uint256 _referrerRate) public {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        __Owned_init();
        console.log("giveToken %s", _giveToken);

        dayRate = _dayRate;
        yearRate = _yearRate;
        giveRate = _giveRate;
        giveToken = _giveToken;
        referrerRate = _referrerRate;
    }
}