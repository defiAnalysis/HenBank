// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract HenBase {
    //白名单
    mapping(address => bool) whiteList;
    //金库地址
    address vault;

    //锁仓记录
    struct LockHistory {
        // address token; //token
        address account; //用户地址
        uint256 id; //锁仓ID
        uint256 day; //天数 0为活期 >0为死期
        uint256 balance; //金额
        uint256 profit; //利润
        uint256 giveProfit; //赠送利润
        uint256 create; //锁仓时间
        bool end; //是否结束
        uint256 update; //最后更新时间(提取后会更新)
    }
    //token对应的所有锁仓记录
    mapping(address => LockHistory[]) public lockHistories;
    //token对应的运行中的记录索引
    mapping(address => uint256[]) public runLockHistories;
    //用户对应的运行中的记录索引
    mapping(address => mapping(address => uint256[])) public runUserLockHistories;

    //用户收益统计，记录用户锁仓资金、收益、利润
    struct Account {
        uint256 lock; //锁仓
        uint256 profit; //收益
        uint256 balance; //可用余额
        uint256 giveProfit; //平台币收益
        uint256 todayProfit; //今日收益
        uint256 referrerProfit; //推荐收益
        uint256 yield; //年化率
    }
    mapping(address => mapping(address => Account)) internal accounts;

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
    //1天有多少秒，用来计算天数
    // uint256 constant daySecond = 60 * 60 * 24;
    uint256 constant daySecond = 60 * 10;
    //日化0.03%
    uint256 public dayRate;
    //年化0.1%
    uint256 public yearRate;
    //赠送代币比例，相对于年化
    uint256 public giveRate;
    //赠送的TOKEN
    address public giveToken;

    //美金币价表，用来计算分多少平台币用的
    mapping(address => uint256) public usdPrices;

    //统计信息
    struct TotalInfo {
        uint256 todayProfit; //今日收益
        uint256 yield; //年化率
        uint256 totalProfit; //总收益
        uint256 giveProfit; //赠送收益
    }
    //收益、赠送、推荐信息
    struct AwardInfo {
        uint256 rate; //兑换比例
        uint256 profit; //收益奖励
        uint256 giveProfit; //赠送奖励
        uint256 referrerProfit; //推荐奖励
    }

    //事件--------------
    //提现
    event Withdraw(address indexed token, address indexed account, uint256 amount, uint256 create);
    //锁仓
    event Lock(uint256 lockId, address indexed token, address indexed account, uint256 amount, uint256 day, uint256 create);
    //解锁
    event Unlock(uint256 lockId, address indexed token, address indexed account, uint256 amount, uint256 create);

    //推荐关系
    mapping(address => address) public referrers;
    //推荐奖励比例
    uint256 public referrerRate;
    //推荐收益表,上级=>(用户=>利润)
    mapping(address => mapping(address => uint256)) public referrerAwards;
    //推荐事件
    event Referrer(address account, address indexed referrer, uint256 create);
}
