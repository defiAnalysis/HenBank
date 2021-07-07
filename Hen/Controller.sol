// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../library/SafeMath.sol";
import "../token/ERC20SafeTransfer.sol";
import "hardhat/console.sol";
import "./Base.sol";

contract HenController is HenBase, ERC20SafeTransfer {
    using SafeMath for uint256;

    //平台
    //---------
    //获取设置
    function getSetting() public view returns (Setting memory) {
        return Setting({rateDecimal: rateDecimal, dayRate: dayRate, yearRate: yearRate, giveToken: giveToken, giveRate: giveRate, referrerRate: referrerRate});
    }

    //获取矿机信息
    function getBank(address _token) public view returns (Bank memory) {
        //今日收益
        (uint256 _todayProfit, uint256 _yield) = totalTodayProfitYield(_token, address(0));
        Bank memory _bank = banks[_token];
        _bank.todayProfit = _todayProfit;
        _bank.yield = _yield;
        return _bank;
    }

    //用户部分
    //---------------------------
    function getAccount(address _token) public view returns (Account memory) {
        return getAccountByAddress(_token, msg.sender);
    }

    function getAccountByAddress(address _token, address _address) public view returns (Account memory) {
        //今日收益
        (uint256 _todayProfit, uint256 _yield) = totalTodayProfitYield(_token, _address);
        Account memory _account = accounts[_token][_address];
        _account.todayProfit = _todayProfit;
        _account.yield = _yield;
        return _account;
    }

    //提现代币
    function withdrawToken(address _token) public {
        require(_token != address(0), "Address is error");
        Account storage _account = accounts[_token][msg.sender];
        //获取余额
        uint256 _balance = _account.balance;
        if (_balance > 0) {
            _account.balance = 0;
            require(doTransferOut(_token, msg.sender, _balance), "Not sufficient funds");
            console.log("withdrawToken %s %d", _token, _balance);
            emit Withdraw(_token, msg.sender, _balance, block.timestamp);
        }
    }

    //锁定用户资金
    function lockToken(
        address _token,
        uint256 _day,
        uint256 _amount,
        address _referrer
    ) public {
        require(_token != address(0), "Address is error");
        require(doTransferFrom(_token, msg.sender, address(this), _amount), "Not sufficient funds");
        //增加推荐
        addReferrer(msg.sender, _referrer);

        uint256 _id = newLockId();
        LockHistory memory lock = LockHistory({account: msg.sender, id: _id, day: _day, balance: _amount, profit: 0, giveProfit: 0, create: block.timestamp, end: false});
        lockHistories[_token].push(lock);
        console.log("lock", _token, _day, _amount);
        //加到锁定
        accounts[_token][msg.sender].lock = accounts[_token][msg.sender].lock.add(_amount);
        //增加矿机总资金
        banks[_token].lock = banks[_token].lock.add(_amount);
        emit Lock(_id, _token, msg.sender, _amount, _day, block.timestamp);
    }

    //解冻用户资金
    function unlock(address _token, uint256 _lockId) public {
        uint256 _index;
        for (uint256 _i = 0; _i < lockHistories[_token].length; _i++) {
            if (lockHistories[_token][_i].id == _lockId) {
                _index = _i;
                break;
            }
        }
        require(lockHistories[_token][_index].account == msg.sender, "Permission denied");
        return unlockToken(_token, _index);
    }

    function unlockToken(address _token, uint256 _index) internal {
        require(_token != address(0), "Address is error");
        LockHistory memory _history = lockHistories[_token][_index];
        require(!_history.end, "Order closed");
        //检查是否到解冻天数
        require(block.timestamp >= _history.create + _history.day * 1 days, "It's not time to unlock");

        //冻结的数量
        uint256 _lockBalance = _history.balance;
        //锁仓减少
        accounts[_token][_history.account].lock = accounts[_token][_history.account].lock.sub(_lockBalance);
        //加到可用
        accounts[_token][_history.account].balance = accounts[_token][_history.account].balance.add(_lockBalance);
        //设置订单状态
        lockHistories[_token][_index].end = true;
        //减少矿机总资金
        banks[_token].lock = banks[_token].lock.sub(_lockBalance);

        emit Unlock(_history.id, _token, _history.account, _lockBalance, block.timestamp);
        console.log("unlock", _history.id, _token, _lockBalance);
    }

    //获取余额
    function getBalance(address _token, address _address) public view returns (Account memory) {
        Account memory _account = accounts[_token][_address];
        return _account;
    }

    //计算或检查部分
    //-----------------------------
    //获取已锁资金
    function getLockBalance(address _token, address _address) public view returns (uint256) {
        uint256 _total;
        for (uint256 i = 0; i < lockHistories[_token].length; i++) {
            LockHistory memory lock = lockHistories[_token][i];
            if (lock.end == false) {
                if (_address == address(0)) {
                    _total = _total.add(lock.balance);
                } else if (_address == lock.account) {
                    _total = _total.add(lock.balance);
                }
            }
        }
        return _total;
    }

    //获取锁仓记录
    function getLockHistory(address _token, uint256 _index) public view returns (LockHistory memory) {
        return lockHistories[_token][_index];
    }

    // function getLockHistoryList(
    //     address _token,
    //     uint256 _p,
    //     uint256 _limit
    // ) public view returns (LockHistory[] memory, uint256) {
    //     _p = _p.sub(1);
    //     uint256 _start = _limit.mul(_p);
    //     uint256 _end = _start.add(_limit);
    //     LockHistory[] memory _history;
    //     uint256 _length;
    //     for (uint256 i = 0; i < lockHistories[_token].length; i++) {
    //         if (lockHistories[_token][i].account == msg.sender) {
    //             _length++;
    //         }
    //     }

    //     _history = new LockHistory[](_length);
    //     uint256 n;
    //     for (uint256 i = 0; i < lockHistories[_token].length; i++) {
    //         if (lockHistories[_token][i].account == msg.sender) {
    //             _history[n] = lockHistories[_token][i];
    //         }
    //     }

    //     if (_start > _length) {
    //         return (_history, _length);
    //     }
    //     if (_length < _end) {
    //         _end = _length;
    //     }
    //     if (_start == _end) {
    //         return (_history, _length);
    //     }

    //     LockHistory[] memory _history2 = new LockHistory[](_end.sub(_start));
    //     n = 0;
    //     for (uint256 i = _start; i < _end; i++) {
    //         _history2[n] = _history[i];
    //         console.log(_history2[n].day, _history2[n].balance, _history2[n].profit);
    //         n++;
    //     }
    //     return (_history, _length);
    // }

    //获取利润比例
    function getRate(uint256 _day) public view returns (uint256) {
        if (_day == 0) {
            _day = 1;
        }
        if (_day <= 0) {
            return 0;
        }
        uint256 _rate = yearRate.sub(dayRate).div(365 - 1);
        uint256 n = dayRate.add(_day.sub(1).mul(_rate));
        return n;
    }

    //统计今日利润
    function totalTodayProfitYield(address _token, address _address) public view returns (uint256, uint256) {
        uint256 _totalProfit;
        uint256 _yield;
        uint256 _n;
        for (uint256 i = 0; i < lockHistories[_token].length; i++) {
            LockHistory memory _history = lockHistories[_token][i];
            uint256 _profit;
            uint256 _rate = getRate(_history.day);
            //如果地址不为0
            if (_address == address(0)) {
                _profit = _history.balance.mul(_rate);
                _yield = _yield.add(_rate);
                _n++;
            } else if (_history.account == _address) {
                _profit = _history.balance.mul(_rate);
                _yield = _yield.add(_rate);
                _n++;
            }
            if (_profit > 0) {
                _profit = _profit.div(10**rateDecimal);
                _totalProfit = _totalProfit.add(_profit);
            }
        }
        if (_n > 0) {
            _yield = _yield.div(_n);
        }
        return (_totalProfit, _yield);
    }

    //不同token之间，精度转换
    function changeAmount(
        address _from,
        address _to,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _fromDecimal = IERC20(_from).decimals();
        uint256 _toDecimal = IERC20(_to).decimals();
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

    //获取ID
    function newLockId() internal returns (uint256) {
        lockId++;
        return lockId;
    }

    //增加推荐关系
    function addReferrer(address _address, address _referrer) internal {
        //推荐人上级不能为当前用户
        if (_address == address(0) || _referrer == address(0) || _address == _referrer || referrers[_address] != address(0) || referrers[_referrer] == _address) {
            return;
        }
        referrers[_address] = _referrer;
        console.log("referrer from %s to %s", _referrer, _address);
        emit Referrer(_address, _referrer, block.timestamp);
    }
}
