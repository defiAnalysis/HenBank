// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;

interface IVault {
    function balance(address _token, address _account) external view returns (uint256);

    function add(
        address _token,
        address _account,
        uint256 _amount
    ) external;

    function sub(
        address _token,
        address _account,
        uint256 _amount
    ) external;

    function deposit(
        address _token,
        address _account,
        uint256 _amount
    ) external;

    function withdraw(
        address _token,
        address _account,
        uint256 _amount
    ) external;

    function unlock(
        address _token,
        address _account,
        uint256 _amount
    ) external;
}
