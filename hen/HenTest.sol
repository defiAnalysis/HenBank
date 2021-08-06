// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Hen.sol";

contract HenTest is Hen {
    //测试
    //改变参与时间
    function testChangeHistoryTime(
        address _token,
        uint256 _index,
        uint256 _day
    ) external onlyOwner {
        lockHistories[_token][_index].update = lockHistories[_token][_index].update.sub(_day);
    }
}
