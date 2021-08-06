// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../library/Owned.sol";
import "./Controller.sol";

contract HenAdmin is Owned, HenController {
    using SafeMath for uint256;

    //设置收益比例
    function adminSetSetting(
        uint256 _day,
        uint256 _year,
        address _giveToken,
        uint256 _give,
        uint256 _referrer
    ) external onlyOwner {
        if (dayRate != _day) {
            dayRate = _day;
        }
        if (yearRate != _year) {
            yearRate = _year;
        }
        if (giveToken != _giveToken) {
            giveToken = _giveToken;
        }
        if (giveRate != _give) {
            giveRate = _give;
        }
        if (_referrer != referrerRate) {
            referrerRate = _referrer;
        }
    }

    //更新币价
    function adminUpdatePrices(address[] calldata _tokens, uint256[] calldata _prices) external onlyOwner {
        require(_tokens.length == _prices.length, "Parameter error");
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            usdPrices[_tokens[_i]] = _prices[_i];
        }
    }
}
