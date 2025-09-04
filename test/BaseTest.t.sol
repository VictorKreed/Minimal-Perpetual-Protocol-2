// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LPManager} from "src/LPManager.sol";
import {PriceOracle} from "src/PriceOracle.sol";
import {PositionManager} from "src/PositionManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {console2} from "forge-std/console2.sol";

abstract contract BaseTest is Test {
    LPManager public lpManager;
    PriceOracle public oracle;
    PositionManager public positionManager;
    address public usdt;
    address public admin1 = makeAddr("admin1");
    address public admin2 = makeAddr("admin2");
    address public lp1 = makeAddr("lp1");
    address public lp2 = makeAddr("lp2");
    address public trader1 = makeAddr("trader1");
    address public trader2 = makeAddr("trader2");

    function setUp() public virtual {
        uint256 fork = vm.createSelectFork("https://eth.merkle.io");
        vm.selectFork(fork);
        assertEq(block.chainid, 1, "Not On Mainnet Fork");
        vm.startBroadcast(admin1);
        usdt = address(new ERC20Mock());
        lpManager = new LPManager(usdt, admin1, admin2);
        oracle = new PriceOracle();
        positionManager = new PositionManager(usdt, address(lpManager), admin1, admin2);

        lpManager.setPostionTradeContract(address(positionManager));
        positionManager.setFeed(address(oracle));

        // Deal Mock Tokens to Traders and LPS
        ERC20Mock(usdt).mint(lp1, 1_000_000e6);
        ERC20Mock(usdt).mint(lp2, 1_000_000e6);
        ERC20Mock(usdt).mint(trader1, 100_000e6);
        ERC20Mock(usdt).mint(trader2, 100_000e6);
        vm.stopBroadcast();
    }
}
