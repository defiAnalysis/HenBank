// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract HenBase {
    //锁ID
    uint256 lockId;

    //锁仓记录
    struct LockHistory {
        address account; //帐户地址
        uint256 id; //锁仓ID
        uint256 day; //天数 0为活期 >0为死期
        uint256 balance; //金额
        uint256 profit; //利润
        uint256 giveProfit; //赠送利润
        uint256 create; //锁仓时间
        bool end; //是否结束
    }
    mapping(address => LockHistory[]) public lockHistories;

    //用户收益统计
    struct Account {
        uint256 lock; //锁仓
        uint256 profit; //利润
        uint256 balance; //可用余额
        uint256 giveTotal; //赠送币的余额
        uint256 todayProfit; //今日收益
        uint256 yield; //年化率
    }
    mapping(address => mapping(address => Account)) internal accounts;

    //代币资金
    // mapping(address => uint256) internal giveBalances;

    // Supports token or not
    // mapping(address => bool) public tokensEnable;
    //存款统计
    struct Bank {
        uint256 lock; //锁仓总资金
        uint256 profit; //利润
        uint256 giveProfit; //赠送的利润
        uint256 todayProfit; //今日收益
        uint256 yield; //年化率
    }
    mapping(address => Bank) internal banks;

    //设置
    struct Setting {
        uint256 rateDecimal;
        uint256 dayRate;
        uint256 yearRate;
        uint256 giveRate;
        address giveToken;
        uint256 referrerRate;
    }
    //分配比例，精度8位
    uint256 public constant rateDecimal = 8;
    //日化0.03%
    uint256 public dayRate;
    //年化0.1%
    uint256 public yearRate;
    //赠送代币比例，相对于年化
    uint256 public giveRate;
    address public giveToken;

    //事件--------------
    //提现
    event Withdraw(address indexed token, address indexed account, uint256 amount, uint256 create);
    //锁仓
    event Lock(uint256 lockId, address indexed token, address indexed account, uint256 amount, uint256 day, uint256 create);
    //解锁
    event Unlock(uint256 lockId, address indexed token, address indexed account, uint256 amount, uint256 create);
    //用户挖币事件
    event Mining(uint256 lockId, address indexed token, address indexed account, uint256 profit, address token2, uint256 profit2, uint256 create);
    //矿机挖币事件
    event TotalMining(address indexed token, uint256 profit, address token2, uint256 profit2, uint256 create);

    //推荐关系
    mapping(address => address) public referrers;
    //推荐奖励比例
    uint256 public referrerRate;
    //推荐奖励事件
    event Award(uint256 lockId, address indexed account, address referrals, address token, uint256 profit, uint256 create);
    //推荐事件
    event Referrer(address account, address indexed referrer, uint256 create);
}
