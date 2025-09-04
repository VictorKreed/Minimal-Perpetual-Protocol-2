// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseTest.t.sol";

contract PositionManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(admin1);
        positionManager.openTradeStatus();
    }

    function test_depositAndWithdraw() public {
        vm.startPrank(trader1);
        positionManager.deposit(1000e6);
        assertEq(positionManager.getUserDeposit(trader1), 1000e6);

        positionManager.withdraw(500e6);
        assertEq(positionManager.getUserDeposit(trader1), 500e6);
        vm.stopPrank();
    }

    function test_openPositionRevertsWhenTooMuchCollateral() public {
        vm.prank(trader1);
        positionManager.deposit(3000e6);

        vm.startPrank(trader1);
        vm.expectRevert("Max 2,000 USDT collateral to open a position");
        positionManager.openPosition(3000e6, 2, PositionManager.PositionType.LONG);
        vm.stopPrank();
    }

    function test_openPositionRevertsAtOver2000Collateral() public {
        vm.prank(trader1);
        positionManager.deposit(3000);

        _mockOraclePrice(2000e8);

        vm.startPrank(trader1);
        vm.expectRevert("Max 2,000 USDT collateral to open a position");
        positionManager.openPosition(2001, 2, PositionManager.PositionType.LONG);
        vm.stopPrank();
    }

    // function test_openPositionAndPnL_LongWin() public {
    //     // Trader deposits 2000 USDT (raw units, no decimals scaling)
    //     vm.prank(trader1);
    //     positionManager.deposit(2000);

    //     // Mock ETH price
    //     int256 startPrice = 2000e8;
    //     _mockOraclePrice(startPrice);

    //     // Open a position with 900 collateral (well below 2000 limit)
    //     vm.prank(trader1);
    //     positionManager.openPosition(900, 2, PositionManager.PositionType.LONG);

    //     // Move ETH price up to simulate profit
    //     int256 endPrice = 2200e8;
    //     _mockOraclePrice(endPrice);

    //     // Assert profit
    //     int256 pnl = positionManager.getPositionPnL(trader1);
    //     assertGt(pnl, 0);
    // }

    // function test_liquidationOnlyWhenThresholdMet() public {
    //     vm.prank(trader1);
    //     positionManager.deposit(2000e6);
    //     _mockOraclePrice(2000e8);

    //     vm.prank(trader1);
    //     positionManager.openPosition(1000e6, 2, PositionManager.PositionType.LONG);

    //     _mockOraclePrice(1000e8); // 50% drop
    //     bool valid = positionManager.isLiquidationValid(trader1);
    //     assertFalse(valid);

    //     _mockOraclePrice(200e8); // 90% drop
    //     valid = positionManager.isLiquidationValid(trader1);
    //     assertTrue(valid);
    // }

    function test_onlyAdminCanResetLeverage() public {
        vm.prank(trader1);
        vm.expectRevert("Only Admin");
        positionManager.resetMaximumLeverage(10);

        vm.prank(admin1);
        positionManager.resetMaximumLeverage(10);
        assertEq(positionManager.maximumLeverage(), 10);
    }

    function _mockOraclePrice(int256 price) internal {
        // override oracle feed with mock that always returns `price`
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(oracle.getChainlinkDataFeedLatestAnswer.selector),
            abi.encode(price, 8)
        );
    }
}
