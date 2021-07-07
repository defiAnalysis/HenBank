// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;

library Common {
    // address[] addressList;
    function zeroTime() public view returns (uint256) {
        return block.timestamp / 86400;
    }

    // function uint2str(uint256 i) internal returns (string memory c) {
    //     if (i == 0) return "0";
    //     uint256 j = i;
    //     uint256 length;
    //     while (j != 0){
    //         length++;
    //         j /= 10;
    //     }
    //     bytes memory bstr = new bytes(length);
    //     uint256 k = length - 1;
    //     while (i != 0){
    //         bstr[k--] = 48 + i % 10;
    //         i /= 10;
    //     }
    //     c = string(bstr);
    // }

    // function saveAddress(address _address) private {
    //     bool exist = false;
    //     for (uint256 i = 0; i < addressList.length; i++) {
    //         if (addressList[i] == _address) {
    //             exist = true;
    //         }
    //     }
    //     if (!exist) {
    //         addressList.push(_address);
    //     }
    // }
}

//比例
library Rates {
    uint256 constant decimal = 4;

    function to(uint256 n) public pure returns (uint256) {
        return n * (10**decimal);
    }
}
