// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ILPManager {
  
    function deposit(uint256 amount) external;

    function getCurrentOwnershipPercent(address lp) external view returns (uint256);

    function getTotalShares() external view returns (uint256);

    function withdrawAll() external;

    function setPostionTradeContract(address newTradeContract) external;

    function approvePostionTradeContract() external;

    function unApprovePostionTradeContract() external;

    function getVaultBalance() external view returns (uint256);
}
