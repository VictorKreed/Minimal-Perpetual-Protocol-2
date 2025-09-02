// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ILPManager {

    enum PositionType {
    LONG,
    SHORT
}
   struct Position {
        uint256 collateralAmount;
        uint256 leveragemultiplier;
        uint256 nativeTokenCurrentPrice; //ETH price at opening time
        uint256 positionsize;  // collateral * leverage
        uint256 nativeTokenExposureAtOpening; //positionSize worth in ETH at opening
        address owner;
        uint openedAt;
        PositionType positionType;
        bool positionActive;
    }

    function deposit(uint256 amount) external;

    function getCurrentOwnershipPercent(address lp) external view returns (uint256);

    function getTotalShares() external view returns (uint256);

    function withdrawAll() external;

    function updateYields(uint256 profits) external;
    
    function setPostionTradeContract(address newTradeContract) external;

    function approvePostionTradeContract() external;

    function unApprovePostionTradeContract() external;
}