// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {FloorToken, IWNATIVE, ILBFactory, ILBPair, IERC20} from "src/FloorToken.sol";

contract TransferTaxFloorTokenTest is Test {
    using Math for uint256;

    IWNATIVE public constant wNative = IWNATIVE(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    ILBFactory public constant lbFactory = ILBFactory(0x8e42f2F4101563bF679975178e880FD87d3eFd4e);
    uint256 constant tokenPerBin = 100e18;
    uint24 constant initId = 1 << 23;
    uint16 constant binStep = 25;
    uint24 constant nbBins = 10;

    MockFloorToken public token;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("avalanche"), 29905253);

        token = new MockFloorToken("Floor", "FLOOR", address(this), wNative, lbFactory, initId, binStep, tokenPerBin);
        token.raiseRoof(nbBins);
    }

    function test_FloorPrice() public {
        assertEq(token.floorPrice(), 1 << 128, "test_FloorPrice::1");
    }

    function test_TokensInPair() public {
        (uint256 tokenAmount, uint256 wNativeAmount) = token.tokensInPair();

        assertEq(tokenAmount, nbBins * tokenPerBin, "test_TokensInPair::1");
        assertEq(wNativeAmount, 0, "test_TokensInPair::2");
    }

    function test_Range() public {
        (uint24 floorId, uint24 roofId) = token.range();

        assertEq(floorId, initId, "test_Range::1");
        assertEq(roofId, initId + nbBins - 1, "test_Range::2");

        token.raiseRoof(1);

        (floorId, roofId) = token.range();

        assertEq(floorId, initId, "test_Range::3");
        assertEq(roofId, initId + nbBins, "test_Range::4");
    }

    function test_PauseRebalance() public {
        assertFalse(token.rebalancePaused(), "test_PauseRebalance::1");

        vm.expectRevert("FloorToken: rebalance already unpaused");
        token.unpauseRebalance();

        token.pauseRebalance();

        assertTrue(token.rebalancePaused(), "test_PauseRebalance::2");

        vm.expectRevert("FloorToken: rebalance paused");
        token.rebalanceFloor();

        vm.expectRevert("FloorToken: rebalance already paused");
        token.pauseRebalance();

        token.unpauseRebalance();

        assertFalse(token.rebalancePaused(), "test_PauseRebalance::3");

        vm.expectRevert("FloorToken: rebalance already unpaused");
        token.unpauseRebalance();
    }

    function test_RaiseRoof() public {
        (uint24 floorId, uint24 roofId) = token.range();

        ILBPair pair = ILBPair(token.pair());

        for (uint24 i = floorId; i <= roofId; i++) {
            uint256 share = pair.balanceOf(address(token), i);
            assertGt(share, 0, "test_RaiseRoof::1");

            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(i);
            uint256 totalShares = pair.totalSupply(i);

            assertEq(share.mulDiv(binReserveX, totalShares), tokenPerBin, "test_RaiseRoof::2");
            assertEq(share.mulDiv(binReserveY, totalShares), 0, "test_RaiseRoof::3");
        }

        token.raiseRoof(5);

        (floorId, roofId) = token.range();

        for (uint24 i = floorId; i <= roofId; i++) {
            uint256 share = pair.balanceOf(address(token), i);
            assertGt(share, 0, "test_RaiseRoof::4");

            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(i);
            uint256 totalShares = pair.totalSupply(i);

            assertEq(share.mulDiv(binReserveX, totalShares), tokenPerBin, "test_RaiseRoof::5");
            assertEq(share.mulDiv(binReserveY, totalShares), 0, "test_RaiseRoof::6");
        }

        vm.expectRevert("FloorToken: invalid nbBins");
        token.raiseRoof(0);

        vm.expectRevert("FloorToken: invalid nbBins");
        token.raiseRoof(type(uint24).max - roofId);
    }

    function test_RebalanceWithHighFees() public {
        vm.prank(lbFactory.owner());
        // increase the base fee to the max to make sure we have enough eth to always increase the floor price when we cross a bin
        lbFactory.setFeesParametersOnPair(IERC20(address(token)), wNative, binStep, 65_535, 0, 0, 0, 0, 0, 0);

        ILBPair pair = ILBPair(token.pair());

        (uint24 floorId, uint24 roofId) = token.range();

        _swapNbBins(pair, false, 3);

        token.rebalanceFloor();

        (uint24 newFloorId, uint24 newRoofId) = token.range();

        assertEq(newFloorId, floorId + 1, "test_RebalanceWithHighFees::1");
        assertEq(newRoofId, roofId, "test_RebalanceWithHighFees::2");

        vm.startPrank(address(1));
        token.transfer(address(pair), token.balanceOf(address(1)));
        pair.swap(true, address(1));
        vm.stopPrank();

        uint24 activeId = pair.getActiveId();

        assertEq(activeId, newFloorId, "test_RebalanceWithHighFees::3");

        _swapNbBins(pair, false, 7);

        // Rebalance should happen on transfer
        vm.startPrank(address(1));
        token.transfer(address(pair), token.balanceOf(address(1)));
        vm.stopPrank();

        (newFloorId, newRoofId) = token.range();

        assertEq(newFloorId, floorId + 7, "test_RebalanceWithHighFees::4");
        assertEq(newRoofId, roofId, "test_RebalanceWithHighFees::5");

        pair.swap(true, address(1));
    }

    function test_RebalanceAndCalculateNewFloorId() public {
        ILBPair pair = ILBPair(token.pair());

        (uint24 floorId, uint24 roofId) = token.range();

        uint256 calculateNewId = token.calculateNewFloorId();

        assertEq(calculateNewId, floorId, "test_RebalanceSimple::1");

        _swapNbBins(pair, false, 10);

        calculateNewId = token.calculateNewFloorId();

        assertEq(roofId, pair.getActiveId(), "test_Rebalance::2");

        vm.startPrank(address(1));
        token.transfer(address(pair), token.balanceOf(address(1)));
        pair.swap(true, address(1));
        vm.stopPrank();

        (uint24 newFloorId1,) = token.range();

        assertGt(newFloorId1, floorId, "test_Rebalance::3");
        assertEq(newFloorId1, calculateNewId, "test_Rebalance::4");
        assertEq(newFloorId1, pair.getActiveId(), "test_Rebalance::5");

        _swapNbBins(pair, false, roofId - newFloorId1);

        calculateNewId = token.calculateNewFloorId();

        assertEq(roofId, pair.getActiveId(), "test_Rebalance::6");

        token.rebalanceFloor();
        (uint24 newFloorId2,) = token.range();

        assertGt(newFloorId2, newFloorId1, "test_Rebalance::7");
        assertEq(newFloorId2, calculateNewId, "test_Rebalance::8");

        vm.expectRevert("FloorToken: no rebalance needed");
        token.rebalanceFloor();

        // transfer to try to trigger a rebalance
        vm.prank(address(1));
        token.transfer(address(1), 1);

        (uint24 newFloorId3,) = token.range();

        assertEq(newFloorId3, newFloorId2, "test_Rebalance::9");
    }

    function _swapNbBins(ILBPair lbPair, bool swapForY, uint24 nbBin) internal {
        require(nbBin > 0, "TestHelper: nbBin must be > 0");

        IERC20 tokenX = lbPair.getTokenX();
        IERC20 tokenY = lbPair.getTokenY();

        uint24 id = lbPair.getActiveId();
        uint128 reserve;

        for (uint24 i = 0; i <= nbBin; i++) {
            uint24 nextId = swapForY ? id - i : id + i;
            (uint128 binReserveX, uint128 binReserveY) = lbPair.getBin(nextId);

            uint128 amount = swapForY ? binReserveY : binReserveX;

            if (i == nbBin) amount /= 2;

            reserve += amount;
        }

        (uint128 amountIn,,) = lbPair.getSwapIn(reserve, swapForY);

        deal(address(swapForY ? tokenX : tokenY), address(this), amountIn);

        (swapForY ? tokenX : tokenY).transfer(address(lbPair), amountIn);

        lbPair.swap(swapForY, address(1));

        require(lbPair.getActiveId() == (swapForY ? id - nbBin : id + nbBin), "invalid active bin");
    }
}

contract MockFloorToken is ERC20, FloorToken {
    constructor(
        string memory name,
        string memory symbol,
        address owner,
        IWNATIVE wNative,
        ILBFactory lbFactory,
        uint24 activeId,
        uint16 binStep,
        uint256 tokenPerBin
    ) FloorToken(wNative, lbFactory, activeId, binStep, tokenPerBin) ERC20(name, symbol) {
        _transferOwnership(owner);
    }

    function totalSupply() public view override(ERC20, FloorToken) returns (uint256) {
        return ERC20.totalSupply();
    }

    function _mint(address account, uint256 amount) internal override(ERC20, FloorToken) {
        ERC20._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, FloorToken) {
        FloorToken._beforeTokenTransfer(from, to, amount);
    }
}
