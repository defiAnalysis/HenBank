// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

library BalancesMap {
    using SafeMath for uint256;

    struct Balances {
        address[] tokens;
        mapping(address => uint256) balances;
    }

    struct Balance {
        address token;
        uint256 amount;
    }

    function add(Balances storage self, address _token, uint256 _amount) external {
        addKey(self, _token);
        self.balances[_token] = self.balances[_token].add(_amount);
    }

    function sub(Balances storage self, address _token, uint256 _amount) external {
        require(self.balances[_token] >= _amount, "Not sufficient funds");
        self.balances[_token] = self.balances[_token].sub(_amount);
    }

    function get(Balances storage self, address _token) external view returns (uint256) {
        return self.balances[_token];
    }

    function getAll(Balances storage self) external view returns (Balance[] memory) {
        uint256 _n;
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.balances[self.tokens[i]] > 0) {
                _n++;
            }
        }
        Balance[] memory balanceList = new Balance[](_n);
        uint256 _m;
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.balances[self.tokens[i]] > 0) {
                balanceList[_m] = Balance({token: self.tokens[i], amount: self.balances[self.tokens[i]]});
                _m++;
            }
        }
        return balanceList;
    }

    function addKey(Balances storage self, address _token) private {
        bool exist;
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                exist = true;
            }
        }
        if (!exist) {
            self.tokens.push(_token);
        }
    }
}
