// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;

/**
 * owned是合约的管理者
 */
contract Owned {
    address public owner;

    /**
     * 初台化构造函数
     */
    // function initialize() public {
    //     owner = msg.sender;
    // }
    function __Owned_init() internal {
        owner = msg.sender;
    }

    /**
     * 判断当前合约调用者是否是合约的所有者
     */
    modifier onlyOwner {
        require(msg.sender == owner, "no owner");
        _;
    }

    /**
     * 合约的所有者指派一个新的管理员
     * @param  newOwner address 新的管理员帐户地址
     */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}
