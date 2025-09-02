// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./ILPManager.sol";

interface IPositionManager {

        enum PositionType {
            LONG,
            SHORT
        }

    struct Position {
        uint256 collateralAmount;
        uint256 leveragemultiplier;
        uint nativeTokenCurrentPrice; //ETH price at opening time
        uint positionsize;  // collateral * leverage
        address owner;
        uint openedAt;
        uint leverage;
        string positionType;
        bool postionActive;
    }

    function openPosition(uint256 collateralAmount, uint256 leverageMultiplier, PositionType positionType) external;

    function closePosition() external;

    function liquidatePosition(address user) external;

    function getPositionPnL(address user) external view returns (int256);

    function isLiquidationValid(address user) external view returns (bool);

    function setMaximumLeverage(uint256 _maxLeverage) external;

    function setLiquidationThreshold(uint256 _threshold) external;

    function TradeStatus() external view returns (bool);

    function closeTradeStatus() external;
}