// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ILBRouter} from "joe-v2/interfaces/ILBRouter.sol";

import {FloorToken, ILBFactory, ILBPair, IERC20, LiquidityConfigurations} from "src/FloorToken.sol";

contract TransferTaxFloorTokenTest is Test {
    using Math for uint256;

    IERC20 public constant wNative = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    ILBFactory public constant lbFactory = ILBFactory(0x8e42f2F4101563bF679975178e880FD87d3eFd4e);
    ILBRouter public constant lbRouter = ILBRouter(0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30);
    uint256 constant tokenPerBin = 100e18;
    uint24 constant initId = 1 << 23;
    uint16 constant binStep = 25;
    uint24 constant nbBins = 10;

    MockFloorToken public token;

    function setUp() public {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl, 29905253);

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

        vm.expectRevert("FloorToken: zero bins");
        token.raiseRoof(0);
    }

    function test_ReduceRoof() public {
        token.range();

        vm.expectRevert("FloorToken: zero bins");
        token.reduceRoof(0);

        vm.expectRevert("FloorToken: new roof not above active bin");
        token.reduceRoof(nbBins + 1);

        vm.expectRevert("FloorToken: roof too low");
        token.reduceRoof(type(uint24).max);

        vm.expectRevert("FloorToken: new roof not above active bin");
        token.reduceRoof(nbBins);

        (uint24 floorId, uint24 roofId) = token.range();

        ILBPair pair = ILBPair(token.pair());

        for (uint24 i = floorId; i <= roofId; i++) {
            uint256 share = pair.balanceOf(address(token), i);
            assertGt(share, 0, "test_ReduceRoof::1");

            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(i);
            uint256 totalShares = pair.totalSupply(i);

            assertEq(share.mulDiv(binReserveX, totalShares), tokenPerBin, "test_ReduceRoof::2");
            assertEq(share.mulDiv(binReserveY, totalShares), 0, "test_ReduceRoof::3");
        }

        token.reduceRoof(5);

        (uint24 newFloorId, uint24 newRoofId) = token.range();

        assertEq(newFloorId, floorId, "test_ReduceRoof::4");
        assertEq(newRoofId, roofId - 5, "test_ReduceRoof::5");

        for (uint24 i = floorId; i <= newRoofId; i++) {
            uint256 share = pair.balanceOf(address(token), i);
            assertGt(share, 0, "test_ReduceRoof::6");

            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(i);
            uint256 totalShares = pair.totalSupply(i);

            assertEq(share.mulDiv(binReserveX, totalShares), tokenPerBin, "test_ReduceRoof::7");
            assertEq(share.mulDiv(binReserveY, totalShares), 0, "test_ReduceRoof::8");
        }

        for (uint24 i = newRoofId + 1; i <= roofId; i++) {
            uint256 share = pair.balanceOf(address(token), i);
            assertEq(share, 0, "test_ReduceRoof::9");
        }
    }

    function test_RaiseRoofWithTokenInThePair() public {
        ILBPair pair = ILBPair(token.pair());

        (uint256 tokenReserves, uint256 wNativeReserves) = pair.getReserves();
        (uint256 tokenProtocolFees, uint256 wNativeProtocolFees) = pair.getProtocolFees();

        uint256 amount = 1;

        deal(address(token), address(this), amount);
        deal(address(wNative), address(this), amount);

        token.transfer(address(pair), amount);
        wNative.transfer(address(pair), amount);

        token.raiseRoof(10);

        uint256 tokenBalance = token.balanceOf(address(pair));
        uint256 wNativeBalance = wNative.balanceOf(address(pair));

        assertEq(
            tokenBalance - (tokenReserves + tokenProtocolFees),
            10 * tokenPerBin + amount,
            "test_RaiseRoofWithTokenInThePair::1"
        );
        assertEq(
            wNativeBalance - (wNativeReserves + wNativeProtocolFees), amount, "test_RaiseRoofWithTokenInThePair::2"
        );

        (tokenReserves, wNativeReserves) = pair.getReserves();
        (tokenProtocolFees, wNativeProtocolFees) = pair.getProtocolFees();

        amount = 10 * tokenPerBin + 1;

        deal(address(token), address(this), amount);
        deal(address(wNative), address(this), amount);

        token.transfer(address(pair), amount);
        wNative.transfer(address(pair), amount);

        token.raiseRoof(10);

        tokenBalance = token.balanceOf(address(pair));
        wNativeBalance = wNative.balanceOf(address(pair));

        // Increase amount by 1, because we already have 1 token in the pair from the previous transfer
        amount += 1;

        assertEq(
            tokenBalance - (tokenReserves + tokenProtocolFees),
            10 * tokenPerBin + amount,
            "test_RaiseRoofWithTokenInThePair::3"
        );
        assertEq(
            wNativeBalance - (wNativeReserves + wNativeProtocolFees), amount, "test_RaiseRoofWithTokenInThePair::4"
        );
    }

    function test_RebalanceWithHighFees() public {
        vm.prank(lbFactory.owner());
        // increase the base fee to the max to make sure we have enough eth to always increase the floor price when we cross a bin
        lbFactory.setFeesParametersOnPair(IERC20(address(token)), wNative, binStep, 65_535, 0, 0, 0, 0, 0, 0);

        ILBPair pair = ILBPair(token.pair());

        (uint24 floorId, uint24 roofId) = token.range();

        // deposit liquidity in the pair, to make sure token is not the only LP
        deal(address(token), address(this), 1e18);
        token.transfer(address(pair), 1e18);
        bytes32[] memory liqParams = new bytes32[](1);
        liqParams[0] = bytes32((uint256(1e18) << (64 + 24)) + (uint256(1e18) << (24)) + floorId);
        pair.mint(address(this), liqParams, address(this));

        _swapNbBins(pair, false, 3);

        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        ids[0] = floorId;
        amounts[0] = pair.balanceOf(address(token), ids[0]) - 1;

        vm.prank(address(token));
        pair.burn(address(token), address(this), ids, amounts);

        token.burnFrom(address(1), token.balanceOf(address(1)) / 2); // Make sure a rebalance will occur by burning a lot of the supply

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

        ids[0] = floorId + 5;
        // ids[0] = newFloorId;
        amounts[0] = pair.balanceOf(address(token), ids[0]) - 1;

        vm.prank(address(token));
        pair.burn(address(token), address(this), ids, amounts);

        token.burnFrom(address(1), token.balanceOf(address(1)) / 2);

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

        assertEq(calculateNewId, floorId, "test_RebalanceAndCalculateNewFloorId::1");

        _swapNbBins(pair, false, 10);

        calculateNewId = token.calculateNewFloorId();

        assertEq(roofId, pair.getActiveId(), "test_RebalanceAndCalculateNewFloorId::2");

        vm.startPrank(address(1));
        token.transfer(address(pair), token.balanceOf(address(1)));
        pair.swap(true, address(1));
        vm.stopPrank();

        (uint24 newFloorId1,) = token.range();

        assertGt(newFloorId1, floorId, "test_RebalanceAndCalculateNewFloorId::3");
        assertEq(newFloorId1, calculateNewId, "test_RebalanceAndCalculateNewFloorId::4");
        assertEq(newFloorId1, pair.getActiveId(), "test_RebalanceAndCalculateNewFloorId::5");

        _swapNbBins(pair, false, roofId - newFloorId1);

        calculateNewId = token.calculateNewFloorId();

        assertEq(roofId, pair.getActiveId(), "test_RebalanceAndCalculateNewFloorId::6");

        token.rebalanceFloor();
        (uint24 newFloorId2,) = token.range();

        assertGt(newFloorId2, newFloorId1, "test_RebalanceAndCalculateNewFloorId::7");
        assertEq(newFloorId2, calculateNewId, "test_RebalanceAndCalculateNewFloorId::8");

        vm.expectRevert("FloorToken: no rebalance needed");
        token.rebalanceFloor();

        // transfer to try to trigger a rebalance
        vm.prank(address(1));
        token.transfer(address(1), 1);

        (uint24 newFloorId3,) = token.range();

        assertEq(newFloorId3, newFloorId2, "test_RebalanceAndCalculateNewFloorId::9");
    }

    function test_RebalanceWhileAddingLiquidity() public {
        address alice = address(1);
        ILBPair lbPair = ILBPair(token.pair());

        _swapNbBins(lbPair, false, 10);

        deal(address(wNative), alice, 100_000e18);

        vm.startPrank(alice);
        wNative.transfer(address(lbPair), 100_000e18);

        // Deal the token directly to the pair to make sure it doesn't trigger any callback
        deal(address(token), address(lbPair), token.balanceOf(address(lbPair)) + 100_000e18);

        int256[] memory deltaIds = new int256[](3);
        deltaIds[0] = -1;
        deltaIds[1] = 0;
        deltaIds[2] = 1;

        uint256[] memory distributionX = new uint256[](3);
        distributionX[0] = 0;
        distributionX[1] = 0.5e18;
        distributionX[2] = 0.5e18;

        uint256[] memory distributionY = new uint256[](3);
        distributionY[0] = 0.5e18;
        distributionY[1] = 0.5e18;
        distributionY[2] = 0;

        ILBRouter.LiquidityParameters memory params = ILBRouter.LiquidityParameters({
            tokenX: IERC20(address(token)),
            tokenY: IERC20(address(wNative)),
            binStep: binStep,
            amountX: 0,
            amountY: 0,
            amountXMin: 100_000e18,
            amountYMin: 100_000e18,
            activeIdDesired: lbPair.getActiveId(),
            idSlippage: 0,
            deltaIds: deltaIds,
            distributionX: distributionX,
            distributionY: distributionY,
            to: alice,
            refundTo: alice,
            deadline: block.timestamp
        });

        token.approve(address(lbRouter), type(uint256).max);
        wNative.approve(address(lbRouter), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILBRouter.LBRouter__AmountSlippageCaught.selector,
                100_000e18,
                100_000e18,
                100_000e18,
                99999999999999999939182
            )
        );
        lbRouter.addLiquidity(params);

        params.amountYMin = params.amountYMin * (1e18 - 1) / 1e18;
        lbRouter.addLiquidity(params);
        vm.stopPrank();
    }

    function test_GoOverActiveId() public {
        ILBPair lbPair = ILBPair(token.pair());

        IERC20 tokenY = lbPair.getTokenY();

        vm.prank(lbFactory.owner());
        lbFactory.setFeesParametersOnPair(IERC20(address(token)), wNative, binStep, 65_535, 0, 0, 0, 0, 0, 0);

        _swapNbBins(lbPair, false, 1);

        (uint128 reserveX,) = lbPair.getReserves();

        vm.startPrank(address(1));
        token.transfer(address(lbPair), token.balanceOf(address(1)));

        bytes32[] memory liqParam = new bytes32[](1);
        liqParam[0] = LiquidityConfigurations.encodeParams(uint64(1e18), uint64(1e18), lbPair.getActiveId() + 10000);

        lbPair.mint(address(1), liqParam, address(1));
        vm.stopPrank();

        (uint256 amountY,,) = lbPair.getSwapIn(reserveX, false);

        uint256 balance = tokenY.balanceOf(address(lbPair));

        deal(address(tokenY), address(lbPair), balance + amountY);

        (amountY,,) = lbPair.getSwapIn(reserveX, false);

        deal(address(tokenY), address(lbPair), balance + amountY + 1);

        vm.expectRevert("FloorToken: active bin above roof");
        lbPair.swap(false, address(1));

        deal(address(tokenY), address(lbPair), balance + amountY);

        lbPair.swap(false, address(1));

        token.rebalanceFloor();

        (uint24 floorId, uint24 roofId) = token.range();

        assertEq(floorId, roofId - 1, "test_GoOverActiveId::1");
        assertEq(roofId, lbPair.getActiveId(), "test_GoOverActiveId::2");

        token.pauseRebalance();

        deal(address(tokenY), address(lbPair), tokenY.balanceOf(address(lbPair)) + 1e18);

        lbPair.swap(false, address(1));

        vm.expectRevert("FloorToken: active bin above roof");
        token.unpauseRebalance();

        vm.expectRevert("FloorToken: new roof not above active bin");
        token.reduceRoof(1);

        vm.expectRevert("FloorToken: active bin above roof");
        token.raiseRoof(1);

        vm.prank(address(1));
        token.transfer(address(lbPair), 1e18);

        lbPair.swap(true, address(1));

        token.unpauseRebalance();

        token.raiseRoof(1);

        vm.expectRevert("FloorToken: new roof not above active bin");
        token.reduceRoof(1);

        token.raiseRoof(1);

        token.reduceRoof(1);

        (floorId, roofId) = token.range();

        assertEq(floorId, lbPair.getActiveId() - 1, "test_GoOverActiveId::3");
        assertEq(roofId, lbPair.getActiveId() + 1, "test_GoOverActiveId::4");
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
        IERC20 wNative,
        ILBFactory lbFactory,
        uint24 activeId,
        uint16 binStep,
        uint256 tokenPerBin
    ) FloorToken(wNative, lbFactory, activeId, binStep, tokenPerBin) ERC20(name, symbol) {
        _transferOwnership(owner);
    }

    function balanceOf(address account) public view override(ERC20, FloorToken) returns (uint256) {
        return ERC20.balanceOf(account);
    }

    function totalSupply() public view override(ERC20, FloorToken) returns (uint256) {
        return ERC20.totalSupply();
    }

    function burnFrom(address account, uint256 amount) public {
        ERC20._burn(account, amount);
    }

    function _mint(address account, uint256 amount) internal override(ERC20, FloorToken) {
        ERC20._mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, FloorToken) {
        ERC20._burn(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, FloorToken) {
        FloorToken._beforeTokenTransfer(from, to, amount);
    }
}
