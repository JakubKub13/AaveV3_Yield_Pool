//SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IYieldPool {
    function depositToken() external view returns (address);

    function balanceOfToken(address _token) external view returns (uint256);

    function supplyTokenTo(uint256 _amount, address _to) external;

    function redeemToken(uint256 _amount) external returns (uint256);
}