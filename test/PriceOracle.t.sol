// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseTest.t.sol";

contract PriceOracleTest is BaseTest {
    function test_setFeed() public {
        vm.prank(admin1);
        oracle.setFeed(address(1234));
        // just make sure it doesn't revert
    }

    function test_getPriceRevertsIfOutdated() public {
        address fakeFeed = address(new MockAggregator());
        vm.prank(admin1);
        oracle.setFeed(fakeFeed);

        vm.expectRevert("Price is outdated");
        oracle.getChainlinkDataFeedLatestAnswer();
    }
}

contract MockAggregator {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 2000e8, 0, block.timestamp - 1 hours, 0);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}
