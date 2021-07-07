// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../library/SafeMath.sol";
import "../library/Owned.sol";
import "../token/ERC20SafeTransfer.sol";
import "./Controller.sol";

contract HenAdmin is Owned, ERC20SafeTransfer, HenController {
    using SafeMath for uint256;

    //管理部分
    //---------------------------
    //开启支持的token
    function enableTokens(address[] calldata _tokens) external onlyOwner {
        //传递过来的开启
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokensEnable[_tokens[i]] = true;
        }
    }

    //禁止token
    function disableTokens(address[] calldata _tokens) external onlyOwner {
        //传递过来的开启
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokensEnable[_tokens[i]] = false;
        }
    }

    function miningRate(
        address _token,
        uint256 _day,
        uint256 _balance,
        address _giveToken,
        uint256 _givePrice
    )
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 _rate = getRate(_day);
        uint256 _rateProfit = _balance.mul(_rate).div(10**rateDecimal);

        uint256 _giveProfit;
        uint256 _referrerProfit;
        //如果存在价格，送等值的代币
        if (_givePrice > 0 && giveRate > 0) {
            _giveProfit = _rateProfit.mul(_givePrice).div(10**rateDecimal).mul(giveRate).div(10**rateDecimal); //币数*币价/送的币价=送的币数*送的比例
            _giveProfit = changeAmount(_token, _giveToken, _giveProfit);
            if (referrerRate > 0) {
                _referrerProfit = _rateProfit.mul(_givePrice).div(10**rateDecimal).mul(referrerRate).div(10**rateDecimal);
                _referrerProfit = changeAmount(_token, _giveToken, _referrerProfit);
            }
        }
        return (_rateProfit, _giveProfit, _referrerProfit);
    }

    function mining(address _token, uint256 _givePrice) public onlyOwner {
        require(_token != address(0), "Address is error");

        uint256 _totalProfit;
        uint256 _giveTotalProfit;
        //先分在解锁
        for (uint256 i = 0; i < lockHistories[_token].length; i++) {
            LockHistory memory _history = lockHistories[_token][i];
            if (!_history.end) {
                (uint256 _rateProfit, uint256 _giveProfit, uint256 _referrerProfit) = miningRate(_token, _history.day, _history.balance, giveToken, _givePrice);
                address _address = _history.account;
                Account storage _account = accounts[_token][_address];
                //挖矿收益
                if (_rateProfit > 0) {
                    //更新统计
                    _account.profit = _account.profit.add(_rateProfit);
                    //加到可用
                    _account.balance = _account.balance.add(_rateProfit);
                    //更新收益
                    lockHistories[_token][i].profit = lockHistories[_token][i].profit.add(_rateProfit);
                    _totalProfit = _totalProfit.add(_rateProfit);
                    console.log("give %s %d", giveToken, _giveProfit);
                }
                //赠送收益
                if (_giveProfit > 0 && giveToken != address(0)) {
                    //更新记录
                    lockHistories[_token][i].giveProfit = lockHistories[_token][i].giveProfit.add(_giveProfit);
                    //加到赠送
                    _account.giveTotal = _account.giveTotal.add(_giveProfit);
                    accounts[giveToken][_address].balance = accounts[giveToken][_address].balance.add(_giveProfit);
                    _giveTotalProfit = _giveTotalProfit.add(_giveProfit);
                    console.log("mining %s %d", _address, _rateProfit);
                }
                //推荐
                address _referrer = referrers[_address];
                if (_referrerProfit > 0 && _referrer != address(0)) {
                    //加到奖励
                    accounts[giveToken][_referrer].balance = accounts[giveToken][_referrer].balance.add(_referrerProfit);
                    emit Award(_history.id, _referrer, _address, giveToken, _referrerProfit, block.timestamp);
                    console.log("award %s %s %d", _referrer, _address, _referrerProfit);
                }
                emit Mining(_history.id, _token, _address, _rateProfit, giveToken, _giveProfit, block.timestamp);
            }
        }
        //解锁到期的
        for (uint256 i = 0; i < lockHistories[_token].length; i++) {
            LockHistory memory _history = lockHistories[_token][i];
            if (!_history.end) {
                //死期超过时间释放
                if (_history.day > 0 && block.timestamp >= _history.create + _history.day * 1 days) {
                    unlockToken(_token, i);
                }
            }
        }

        if (_totalProfit > 0) {
            //增加矿机收益
            banks[_token].profit = banks[_token].profit.add(_totalProfit);
            if (_giveTotalProfit > 0) {
                banks[_token].giveProfit = banks[_token].giveProfit.add(_giveTotalProfit);
            }
            console.log("total", _totalProfit, banks[_token].profit);
            emit TotalMining(_token, _totalProfit, giveToken, _giveTotalProfit, block.timestamp);
        }
    }

    //多挖
    function minings(address[] memory _tokens, uint256[] memory _givePrices) public onlyOwner {
        require(_tokens.length == _givePrices.length, "Parameter error");
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            mining(_tokens[_i], _givePrices[_i]);
        }
    }

    //测试
    function changeHistoryCreate(
        address _token,
        uint256 _index,
        uint256 _day
    ) external onlyOwner {
        lockHistories[_token][_index].create -= _day;
    }

    //设置收益比例
    function setSetting(
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

    //提出代币
    function adminLoan(address _token, uint256 _amount) external onlyOwner {
        require(doTransferOut(_token, msg.sender, _amount), "Not sufficient funds");
    }

    //充值代币
    function adminRefund(address _token, uint256 _amount) external onlyOwner {
        require(doTransferFrom(_token, msg.sender, address(this), _amount), "Not sufficient funds");
        console.log("refund %s %d", _token, _amount);
    }
}
