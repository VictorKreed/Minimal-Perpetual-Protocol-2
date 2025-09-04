// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseTest.t.sol";

contract LPManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_firstDeposit() public {
        console2.log("USDT Balance of LP1 : ", ERC20Mock(usdt).balanceOf(lp1));
        _deposit(lp1, 20_000e6);
        assertEq(lpManager.totalShares(), 20_000e6);
        uint256 ownership = lpManager.getCurrentOwnershipPercent(lp1);
        assertEq(ownership, 10000); // 100% for first depositor
    }

    function test_withdrawFailsWhenActiveTrades() public {
        // Open trade to set TradeisActive=true
        _deposit(lp1, 50_000e6);

        _openPosition(trader1, 2000e6, 2, PositionManager.PositionType.LONG);

        vm.startPrank(lp1);
        vm.expectRevert();
        lpManager.withdrawAll();
        vm.stopPrank();
    }

    function _deposit(address lp, uint256 amount) internal {
        vm.startPrank(lp);
        lpManager.deposit(amount);
        vm.stopPrank();
    }

    function _openPosition(
        address trader,
        uint256 amount,
        uint256 leverageMultiplier,
        PositionManager.PositionType positionType
    ) internal {
        vm.startPrank(trader);
        positionManager.openPosition(amount, leverageMultiplier, positionType);
        vm.stopPrank();
    }

    function _depositAndOpenPosition(address trader, uint256 amount) internal {
        _deposit(trader, amount);
    }
}
