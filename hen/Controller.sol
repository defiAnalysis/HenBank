// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../library/SafeMath.sol";
import "../interface/IERC20.sol";
import "../interface/Vault.sol";
import "hardhat/console.sol";
import "./Base.sol";

contract HenController is HenBase {
    using SafeMath for uint256;

    //平台
    //---------
    //获取设置
    function getSetting() public view returns (Setting memory) {
        return Setting({rateDecimal: rateDecimal, dayRate: dayRate, yearRate: yearRate, giveToken: giveToken, giveRate: giveRate, referrerRate: referrerRate});
    }

    //获取银行信息
    function getBank(address _token) public view returns (Bank memory) {
        //今日收益
        TotalInfo memory totalInfo = totalLockHistory(_token, address(0));
        Bank memory _bank = banks[_token];
        _bank.todayProfit = totalInfo.todayProfit;
        _bank.yield = totalInfo.yield;
        //已分配利润+待分配利润=总利润
        _bank.profit = _bank.profit.add(totalInfo.totalProfit);
        _bank.giveProfit = _bank.giveProfit.add(totalInfo.giveProfit);
        return _bank;
    }

    //用户部分
    //---------------------------
    function getAccount(address _token, address _address) public view returns (Account memory) {
        //今日收益
        TotalInfo memory totalInfo = totalLockHistory(_token, _address);
        Account memory _account = accounts[_token][_address];
        _account.todayProfit = totalInfo.todayProfit;
        _account.yield = totalInfo.yield;
        //可用，已分配+待提取=总可用
        _account.balance = IVault(vault).balance(_token, _address).add(totalInfo.totalProfit);
        //已分配利润+待提取=总利润
        _account.profit = _account.profit.add(totalInfo.totalProfit);
        //赠送利润+待分配赠送利润=总赠送利润
        _account.giveProfit = _account.giveProfit.add(totalInfo.giveProfit);
        return _account;
    }

    //提取利润，通过锁仓记录里的update时间，计算可以得到的利润
    //1.将利润加到accounts[用户地址].balance的可用里
    //2.更新update时间
    modifier updateBalance(address _token, address _account) {
        //待领取收益
        uint256 _totalProfit;
        //赠送代币
        uint256 _giveProfit;
        //推荐奖励
        uint256 _referrerProfit;
        for (uint256 _i = 0; _i < runUserLockHistories[_token][_account].length; _i++) {
            //获取索引
            uint256 _index = runUserLockHistories[_token][_account][_i];
            //通过索引获取记录
            LockHistory storage _history = lockHistories[_token][_index];
            if (_history.end) {
                continue;
            }
            //如果为用户地址
            if (_history.account == _account) {
                //算出进行了几天，运行天数*每天的利润=待提取的利润
                uint256 _day = block.timestamp.sub(_history.update).div(daySecond);
                if (_day > 0) {
                    AwardInfo memory awardInfo = miningRate(_token, _history);
                    uint256 _profit = awardInfo.profit.mul(_day);
                    //更新记录里的收益统计
                    _history.profit = _history.profit.add(_profit);

                    _totalProfit = _totalProfit.add(_profit);
                    if (awardInfo.giveProfit > 0) {
                        uint256 _give = awardInfo.giveProfit.mul(_day);
                        //更新记录里的赠送统计
                        _history.giveProfit = _history.giveProfit.add(_give);
                        _giveProfit = _giveProfit.add(_give);
                    }
                    if (awardInfo.referrerProfit > 0) {
                        _referrerProfit = _referrerProfit.add(awardInfo.referrerProfit.mul(_day));
                    }
                    //更新提取时间
                    _history.update = block.timestamp;
                }
            }
        }
        //更新可用
        if (_totalProfit > 0) {
            //加到用户可用
            IVault(vault).addProfit(_token, _account, _totalProfit);
            //更新用户利润
            accounts[_token][_account].profit = accounts[_token][_account].profit.add(_totalProfit);
            //更新该token，代币总利润
            banks[_token].profit = banks[_token].profit.add(_totalProfit);
        }
        //更新赠送
        if (_giveProfit > 0) {
            //加到用户可用
            IVault(vault).addProfit(giveToken, msg.sender, _giveProfit);
            //更新用户赠送平台币统计
            accounts[giveToken][msg.sender].giveProfit = accounts[giveToken][msg.sender].giveProfit.add(_giveProfit);

            //更新该token, 平台币总利润
            banks[_token].giveProfit = banks[_token].giveProfit.add(_giveProfit);
        }
        //更新推荐收益
        if (_referrerProfit > 0) {
            address _referrer = referrers[msg.sender];
            //加到推荐用户可用
            IVault(vault).addProfit(giveToken, _referrer, _referrerProfit);
            //更新用户推荐收益统计
            accounts[giveToken][_referrer].referrerProfit = accounts[giveToken][_referrer].referrerProfit.add(_referrerProfit);
            //推荐奖励统计
            referrerAwards[_referrer][msg.sender] = referrerAwards[_referrer][msg.sender].add(_referrerProfit);
            // console.log("award %s %s %d", _referrer, msg.sender, _referrerProfit);
        }
        _;
    }

    //提现代币
    function withdrawToken(address _token) external updateBalance(_token, msg.sender) {
        require(_token != address(0), "Address is error");
        uint256 _balance = IVault(vault).balance(_token, msg.sender);
        //清空可用余额
        if (_balance > 0) {
            IVault(vault).withdraw(_token, msg.sender, _balance);
            emit Withdraw(_token, msg.sender, _balance, block.timestamp);
        }
    }

    //同意风险，加入白名单
    function agreeRisk() external {
        whiteList[msg.sender] = true;
    }

    //锁定用户资金
    function lockToken(
        address _token,
        uint256 _day,
        uint256 _amount,
        address _referrer
    ) public {
        //验证是否在白名单
        require(whiteList[msg.sender], "Please agree to");
        require(_token != address(0), "Address is error");
        IVault(vault).deposit(_token, msg.sender, _amount);
        //增加推荐
        addReferrer(msg.sender, _referrer);

        uint256 _id = lockHistories[_token].length;
        LockHistory memory lock = LockHistory({account: msg.sender, id: _id, day: _day, balance: _amount, profit: 0, giveProfit: 0, create: block.timestamp, update: block.timestamp, end: false});
        lockHistories[_token].push(lock);
        // console.log("lock", _token, _day, _amount);
        //加到锁定
        accounts[_token][msg.sender].lock = accounts[_token][msg.sender].lock.add(_amount);
        //填加索引记录
        addHistoryIndex(_token, msg.sender, _id);

        //增加矿机总资金
        banks[_token].lock = banks[_token].lock.add(_amount);
        emit Lock(_id, _token, msg.sender, _amount, _day, block.timestamp);
    }

    //解冻用户资金
    function unlock(address _token, uint256 _index) public updateBalance(_token, msg.sender) {
        LockHistory storage _history = lockHistories[_token][_index];
        require(_history.account == msg.sender, "Permission denied");
        require(!_history.end, "Order closed");
        //检查是否到解冻天数
        require(block.timestamp >= _history.create + _history.day * 1 days, "It's not time to unlock");

        //冻结的数量
        uint256 _lockBalance = _history.balance;
        //锁仓减少
        accounts[_token][_history.account].lock = accounts[_token][_history.account].lock.sub(_lockBalance);
        //加到可用
        IVault(vault).unlock(_token, _history.account, _lockBalance);

        //设置订单状态
        _history.end = true;
        //减少矿机总资金
        banks[_token].lock = banks[_token].lock.sub(_lockBalance);
        //删除索引记录
        delHistoryIndex(_token, _history.account, _index);

        emit Unlock(_history.id, _token, _history.account, _lockBalance, block.timestamp);
        // console.log("unlock", _history.id, _token, _lockBalance);
    }

    //获取利润比例
    function getDayRate(uint256 _day) public view returns (uint256) {
        if (_day == 0) {
            _day = 1;
        } else if (_day > 365) {
            _day = 365;
        }
        uint256 _rate = yearRate.sub(dayRate).div(365 - 1);
        return dayRate.add(_day.sub(1).mul(_rate));
    }

    //通过价格, 获取兑换比例
    function getPriceRate(address _from, address _to) public view returns (uint256) {
        uint256 _fromPrice = usdPrices[_from];
        uint256 _toPrice = usdPrices[_to];
        if (_fromPrice == 0 || _toPrice == 0) {
            return 0;
        }
        return _fromPrice.div(_toPrice);
    }

    //收益分配比例
    function miningRate(address _token, LockHistory memory _history) internal view returns (AwardInfo memory) {
        uint256 _giveProfit;
        uint256 _referrerProfit;
        uint256 _rate = getDayRate(_history.day);
        uint256 _profit = _history.balance.mul(_rate).div(10**rateDecimal);

        uint256 _givePrice = getPriceRate(_token, giveToken);

        //如果存在价格，送等值的代币
        if (_givePrice > 0 && giveRate > 0 && giveToken != address(0)) {
            _giveProfit = _profit.mul(_givePrice).mul(giveRate).div(10**rateDecimal); //币数*币价/送的币价=送的币数*送的比例
            _giveProfit = changeAmount(_token, giveToken, _giveProfit);
            //存在推荐比例
            if (referrerRate > 0) {
                address _referrer = referrers[_history.account];
                //存在推荐人才有推荐奖励
                if (_referrer != address(0)) {
                    _referrerProfit = _profit.mul(_givePrice).mul(referrerRate).div(10**rateDecimal);
                    _referrerProfit = changeAmount(_token, giveToken, _referrerProfit);
                }
            }
        }
        AwardInfo memory info = AwardInfo({rate: _rate, profit: _profit, giveProfit: _giveProfit, referrerProfit: _referrerProfit});
        return info;
    }

    //根据锁记录统计，今日收益、年化率、总收益
    function totalLockHistory(address _token, address _address) public view returns (TotalInfo memory) {
        uint256 _todayProfit; //今日收益
        uint256 _yield; //平均年化率
        uint256 _n; //匹配记录数
        uint256 _totalProfit; //待提取总收益
        uint256 _giveTotalProfit; //赠送币收益

        uint256[] memory _historyList;
        //如果是查全部
        if (_address == address(0)) {
            _historyList = runLockHistories[_token];
        } else {
            //如果是查用户
            _historyList = runUserLockHistories[_token][_address];
        }
        for (uint256 _i = 0; _i < _historyList.length; _i++) {
            uint256 _index = _historyList[_i];
            LockHistory memory _history = lockHistories[_token][_index];
            //检查是否结束\检查token
            if (_history.end) {
                continue;
            }
            //如果查找地址为0或为用户地址
            if (_address == address(0) || _history.account == _address) {
                AwardInfo memory awardInfo = miningRate(_token, _history);
                _yield = _yield.add(awardInfo.rate);
                _n++;
                _todayProfit = _todayProfit.add(awardInfo.profit);

                //算出进行了几天，运行天数*每天的利润=待提取的利润
                uint256 _day = block.timestamp.sub(_history.update).div(daySecond);
                if (_day > 0) {
                    _totalProfit = _totalProfit.add(awardInfo.profit.mul(_day));
                    if (awardInfo.giveProfit > 0) {
                        _giveTotalProfit = _giveTotalProfit.add(awardInfo.giveProfit.mul(_day));
                    }
                }
            }
        }
        if (_n > 0) {
            _yield = _yield.div(_n);
        }
        TotalInfo memory info = TotalInfo({todayProfit: _todayProfit, yield: _yield, totalProfit: _totalProfit, giveProfit: _giveTotalProfit});
        return info;
    }

    //不同token之间，精度转换
    function changeAmount(
        address _from,
        address _to,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _fromDecimal = IERC20(_from).decimals();
        uint256 _toDecimal = IERC20(_to).decimals();
        //如果获取不到合约的精度，
        if (_fromDecimal > _toDecimal) {
            //from大于to，需要除以多出的位数
            uint256 _less = _fromDecimal.sub(_toDecimal);
            return _amount.div(10**_less);
        } else if (_fromDecimal < _toDecimal) {
            //from小于to，需要x多出的位数
            uint256 _less = _toDecimal.sub(_fromDecimal);
            return _amount.mul(10**_less);
        } else {
            //精度相同不转换
            return _amount;
        }
    }

    //增加推荐关系
    function addReferrer(address _address, address _referrer) internal {
        //推荐人上级不能为当前用户
        if (
            _address == address(0) ||
            _referrer == address(0) || //地址不能为空
            _address == _referrer || //地址不能相同
            referrers[_address] != address(0) || //还没推荐关系
            referrers[_referrer] == _address //上级推荐人不能是自己
        ) {
            return;
        }
        referrers[_address] = _referrer;
        // console.log("referrer from %s to %s", _referrer, _address);
        emit Referrer(_address, _referrer, block.timestamp);
    }

    //获取推荐收益
    function getReferrerAward(address _referrer, address _account) external view returns (uint256) {
        return referrerAwards[_referrer][_account];
    }

    //增加锁仓索引
    function addHistoryIndex(
        address _token,
        address _account,
        uint256 _id
    ) private {
        runLockHistories[_token].push(_id);
        runUserLockHistories[_token][_account].push(_id);
    }

    //删除锁仓索引
    function delHistoryIndex(
        address _token,
        address _account,
        uint256 _id
    ) private {
        // console.log(runLockHistories[_token].length, runUserLockHistories[_token][_account].length);
        for (uint256 _i = 0; _i < runLockHistories[_token].length; _i++) {
            if (runLockHistories[_token][_i] == _id) {
                runLockHistories[_token][_i] = runLockHistories[_token][runLockHistories[_token].length - 1];
                runLockHistories[_token].pop();
            }
        }
        for (uint256 _i = 0; _i < runUserLockHistories[_token][_account].length; _i++) {
            if (runUserLockHistories[_token][_account][_i] == _id) {
                runUserLockHistories[_token][_account][_i] = runUserLockHistories[_token][_account][runUserLockHistories[_token][_account].length - 1];
                runUserLockHistories[_token][_account].pop();
            }
        }
        // console.log(runLockHistories[_token][1], runUserLockHistories[_token][_account].length);
    }
}
