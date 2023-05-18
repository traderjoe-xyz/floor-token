// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ILBPair} from "joe-v2/interfaces/ILBPair.sol";

interface IFloorToken {
    event FloorRaised(uint256 newFloorId);

    event RoofRaised(uint256 newRoofId);

    event RebalancePaused();

    event RebalanceUnpaused();

    function pair() external view returns (ILBPair);

    function floorPrice() external view returns (uint256);

    function range() external view returns (uint24, uint24);

    function rebalancePaused() external view returns (bool);

    function tokensInPair() external view returns (uint256, uint256);

    function calculateNewFloorId() external view returns (uint24);

    function totalSupply() external view returns (uint256);

    function rebalanceFloor() external;

    function raiseRoof(uint24 nbBins) external;

    function pauseRebalance() external;

    function unpauseRebalance() external;
}
