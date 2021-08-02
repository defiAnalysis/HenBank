// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../library/Owned.sol";
import "../library/SafeMath.sol";
import "../token/ERC20SafeTransfer.sol";
import "hardhat/console.sol";

contract Vault is Owned, ERC20SafeTransfer {
    using SafeMath for uint256;

    //资金池
    mapping(address => uint256) pools;
    //用户资金表
    mapping(address => mapping(address => uint256)) balances;
    //用户锁仓资金表
    mapping(address => mapping(address => uint256)) locks;
    //借款资金表
    mapping(address => mapping(address => uint256)) loans;
    //支持token

    //工厂合约地址
    address public factory;
    //管理合约地址
    address public manger;

    //只有工厂地址可以充取
    modifier onlyFactory() {
        require(msg.sender == factory, "no factory");
        _;
    }
    //只有管理者可以借款
    modifier onlyManger() {
        require(msg.sender == manger, "no manger");
        _;
    }

    //获取资金
    function balance(address _token, address _account) external view returns (uint256) {
        return balances[_token][_account];
    }

    //增加资金
    function add(
        address _token,
        address _account,
        uint256 _amount
    ) public onlyFactory {
        //加到资金池
        pools[_token] = pools[_token].add(_amount);
        //加到用户资金表
        balances[_token][_account] = balances[_token][_account].add(_amount);
    }

    //减少资金
    function sub(
        address _token,
        address _account,
        uint256 _amount
    ) public onlyFactory {
        require(pools[_token] >= _amount, "Pool not enough");
        require(balances[_token][_account] >= _amount, "Not sufficient funds");
        //从资金池扣除
        pools[_token] = pools[_token].sub(_amount);
        //扣除用户资金表
        balances[_token][_account] = balances[_token][_account].sub(_amount);
    }

    //存入
    function deposit(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyFactory {
        require(doTransferFrom(_token, _account, address(this), _amount), "Not sufficient funds");
        //加到资金池
        pools[_token] = pools[_token].add(_amount);
        //加到用户锁仓表
        locks[_token][_account] = locks[_token][_account].add(_amount);
    }

    //解锁
    function unlock(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyFactory {
        require(locks[_token][_account] >= _amount, "Lock not enough");
        //扣除用户锁仓表
        locks[_token][_account] = locks[_token][_account].sub(_amount);
        //加到用户资金表
        balances[_token][_account] = balances[_token][_account].add(_amount);
    }

    //取出
    function withdraw(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyFactory {
        sub(_token, _account, _amount);
        require(doTransferOut(_token, _account, _amount), "Not sufficient funds");
    }

    //查询资金池有多少币
    function getPool(address _token) external view returns (uint256) {
        return pools[_token];
    }

    //------------------------------------管理-----------------------------------
    //借出
    function lend(address _token, uint256 _amount) external onlyManger {
        require(pools[_token] >= _amount, "pool not enough");
        //从资金池扣除
        pools[_token] = pools[_token].sub(_amount);
        //增加借出
        loans[_token][manger] = loans[_token][manger].add(_amount);
        require(doTransferOut(_token, manger, _amount), "Not sufficient funds");
    }

    //借入，还款
    function borrow(address _token, uint256 _amount) external onlyManger {
        require(doTransferFrom(_token, msg.sender, address(this), _amount), "Not sufficient funds");
        //加到资金池
        pools[_token] = pools[_token].add(_amount);
        //减少借出
        loans[_token][manger] = loans[_token][manger].sub(_amount);
    }

    //存收益到资金池
    function depositPool(address _token, uint256 _amount) external onlyManger {
        require(doTransferFrom(_token, msg.sender, address(this), _amount), "Not sufficient funds");
        //加到资金池
        pools[_token] = pools[_token].add(_amount);
    }

    //设置管理者
    function setManger(address _account) external onlyManger {
        manger = _account;
    }

    //设置工厂地址
    function setFactory(address _account) external onlyManger {
        factory = _account;
    }

    bool private initialized;

    function initialize() public {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        manger = msg.sender;
    }
}
