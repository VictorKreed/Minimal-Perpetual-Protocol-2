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

    // function test_withdrawFailsWhenActiveTrades() public {
    //     // Open trade to set TradeisActive=true
    //     _deposit(lp1, 50_000e6);

    //     _openPosition(trader1, 2000e6, 2, PositionManager.PositionType.LONG);

    //     vm.startPrank(lp1);
    //     vm.expectRevert();
    //     lpManager.withdrawAll();
    //     vm.stopPrank();
    // }

    function test_multipleDepositsUpdateOwnership() public {
        _deposit(lp1, 50_000e6);
        _deposit(lp2, 50_000e6);

        uint256 ownership1 = lpManager.getCurrentOwnershipPercent(lp1);
        uint256 ownership2 = lpManager.getCurrentOwnershipPercent(lp2);

        assertEq(ownership1, 5000); // 50%
        assertEq(ownership2, 5000); // 50%
    }

    function test_withdrawAllResetsShares() public {
        _deposit(lp1, 30_000e6);

        vm.startPrank(lp1);
        lpManager.withdrawAll();
        vm.stopPrank();

        assertEq(lpManager.totalShares(), 0);
        assertEq(lpManager.getCurrentOwnershipPercent(lp1), 0);
    }

    function test_withdrawRevertsIfNoShares() public {
        vm.startPrank(lp1);
        vm.expectRevert("No shares to withdraw");
        lpManager.withdrawAll();
        vm.stopPrank();
    }

    function test_onlyAdminCanSetTradeContract() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert("Only an Administrator can call this Function");
        lpManager.setPostionTradeContract(attacker);
    }

    function test_onlyTradeContractCanApprove() public {
        vm.prank(lp1);
        vm.expectRevert("Only the trading contract can call this function");
        lpManager.approvePostionTradeContract();
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
}
