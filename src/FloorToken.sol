// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ILBFactory, ILBPair, IERC20} from "joe-v2/interfaces/ILBFactory.sol";
import {IWNATIVE} from "joe-v2/interfaces/IWNATIVE.sol";
import {LiquidityConfigurations} from "joe-v2/libraries/math/LiquidityConfigurations.sol";
import {PriceHelper, Uint256x256Math, Constants} from "joe-v2/libraries/PriceHelper.sol";
import {PackedUint128Math} from "joe-v2/libraries/math/PackedUint128Math.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {IFloorToken} from "./interfaces/IFloorToken.sol";

/**
 * @title Floor Token
 * @author Trader Joe
 * @notice The Floor Token contract is made to be inherited by an ERC20-compatible contract.
 * It allows to create a floor for the token, which guarantees that the price of the token will never go below
 * the floor price. On every transfer, the floor will be rebalanced if needed, that is if the amount of wNative
 * available in the pair contract allows to raise the floor by at least one bin.
 * WARNING: The floor mechanism only works if the tokens that are minted are only minted and added as liquidity
 * to the pair contract. If the tokens are minted and sent to an account, the floor mechanism will not work.
 */
abstract contract FloorToken is Ownable2Step, IFloorToken {
    using Uint256x256Math for uint256;
    using PriceHelper for uint24;
    using PackedUint128Math for bytes32;

    uint256 private constant _MAX_NUM_BINS = 100;
    uint8 private constant _STATUS_NOT_ENTERED = 1;
    uint8 private constant _STATUS_ENTERED = 2;

    IWNATIVE private immutable _wNative;
    ILBPair private immutable _pair;
    uint16 private immutable _binStep;
    uint256 private immutable _tokenPerBin;

    uint24 private _floorId;
    uint24 private _roofId;
    bool private _rebalancePaused;
    uint8 private _status;

    /**
     * @notice Modifier to make sure that the function is not reentrant.
     */
    modifier nonReentrant() {
        require(_status == _STATUS_NOT_ENTERED, "FloorToken: reentrant call");
        _status = _STATUS_ENTERED;
        _;
        _status = _STATUS_NOT_ENTERED;
    }

    /**
     * @notice Constructor that initializes the contracts' parameters.
     * @dev The constructor will also deploy a new LB pair contract.
     * @param wNative The address of the wrapped native token.
     * @param lbFactory The address of the LB factory, only work with v2.1.
     * @param activeId The id of the active bin, this is the price floor, calculated as:
     * `(1 + binStep / 10000) ^ (activeId - 2^23)`
     * @param binStep The step between each bin, in basis points.
     * @param tokenPerBin The amount of tokens that will be minted to the pair contract for each bin.
     */
    constructor(IWNATIVE wNative, ILBFactory lbFactory, uint24 activeId, uint16 binStep, uint256 tokenPerBin) {
        _binStep = binStep;
        _tokenPerBin = tokenPerBin;
        _wNative = wNative;

        // Create the pair contract at `activeId - 1` to make sure no one can add `wNative` to the floor or above
        _pair = lbFactory.createLBPair(IERC20(address(this)), IERC20(wNative), activeId - 1, binStep);

        _floorId = activeId;
        _status = _STATUS_NOT_ENTERED;
    }

    /**
     * @notice Returns the address of the pair contract where the tokens are paired with wNative.
     * @return The address of the pair contract.
     */
    function pair() public view virtual override returns (ILBPair) {
        return _pair;
    }

    /**
     * @notice Returns the price floor of the token, in 128.128 fixed point format.
     * @return The price floor of the token, in 128.128 fixed point format.
     */
    function floorPrice() public view virtual override returns (uint256) {
        return _floorId.getPriceFromId(_binStep);
    }

    /**
     * @notice Returns the range of the position, the floor and the roof bin ids.
     * @return The floor bin id.
     * @return The roof bin id.
     */
    function range() public view virtual override returns (uint24, uint24) {
        return (_floorId, _roofId);
    }

    /**
     * @notice Returns whether the rebalance is paused or not.
     * @return Whether the rebalance is paused or not.
     */
    function rebalancePaused() public view virtual override returns (bool) {
        return _rebalancePaused;
    }

    /**
     * @notice Returns the amount of tokens that are paired in the pair contract as locked liquidity.
     * @return token The amount of tokens that are paired in the pair contract as locked liquidity.
     * @return wNative The amount of wNative that are paired in the pair contract as locked liquidity.
     */
    function tokensInPair() public view virtual override returns (uint256 token, uint256 wNative) {
        (token, wNative,,) = _getAmountsInPair(_floorId, _pair.getActiveId(), _roofId);
    }

    /**
     * @notice Returns the new floor id if the floor was to be rebalanced.
     * @dev If the new floor id is the same as the current floor id, it means that no rebalance is needed.
     * @return The new floor id if the floor was to be rebalanced.
     */
    function calculateNewFloorId() public view virtual override returns (uint24) {
        uint24 floorId = _floorId;
        uint24 activeId = _pair.getActiveId();

        (uint256 totalTokenInPair, uint256 totalWNativeInPair,, uint256[] memory wNativeReserves) =
            _getAmountsInPair(floorId, activeId, _roofId);

        uint256 tokenInCirculation = totalSupply() - totalTokenInPair;

        return _calculateNewFloorId(floorId, activeId, tokenInCirculation, totalWNativeInPair, wNativeReserves);
    }

    /**
     * @notice Returns the amount of tokens owned by `account`.
     * @dev This function needs to be overriden by the child contract.
     * @param account The account to get the balance of.
     * @return The amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view virtual override returns (uint256);

    /**
     * @notice Returns the total supply of the token.
     * @dev This function needs to be overriden by the child contract.
     * @return The total supply of the token.
     */
    function totalSupply() public view virtual override returns (uint256);

    /**
     * @notice Force the floor to be rebalanced, in case it wasn't done automatically.
     * @dev This function can be called by anyone, but only if the rebalance is not paused and if the floor
     * needs to be rebalanced.
     * The nonReentrant check is done in `_safeRebalance`.
     */
    function rebalanceFloor() public virtual override {
        require(!_rebalancePaused, "FloorToken: rebalance paused");
        require(_rebalanceFloor(), "FloorToken: no rebalance needed");
    }

    /**
     * @notice Raises the floor by `nbBins` bins. New tokens will be minted to the pair contract and directly
     * added to new bins that weren't previously in the range. This will not decrease the floor price as the
     * tokens are minted are directly added to the pair contract, so the circulating supply is not increased.
     * @dev The new roof will be `roofId + nbBins`, if the roof wasn't already raised, the new roof will be
     * `floorId + nbBins - 1`. Only callable by the owner.
     * This functions should not be called too often as it will increase the gas cost of the transfers, and
     * might even make the transfers if the transaction runs out of gas. It is recommended to only call this
     * function when the floor is close to the roof.
     * The nonReentrant check is done in `_raiseRoof`.
     * @param nbBins The number of bins to raise the floor by.
     */
    function raiseRoof(uint24 nbBins) public virtual override onlyOwner {
        _raiseRoof(_roofId, _floorId, nbBins);
    }

    /**
     * @notice Pauses the rebalance of the floor.
     * @dev Only callable by the owner.
     */
    function pauseRebalance() public virtual override onlyOwner {
        require(!_rebalancePaused, "FloorToken: rebalance already paused");

        _rebalancePaused = true;

        emit RebalancePaused();
    }

    /**
     * @notice Unpauses the rebalance of the floor.
     * @dev Only callable by the owner.
     */
    function unpauseRebalance() public virtual override onlyOwner {
        require(_rebalancePaused, "FloorToken: rebalance already unpaused");

        _rebalancePaused = false;

        emit RebalanceUnpaused();
    }

    /**
     * @dev Returns the amount of tokens and wNative that are in the pair contract.
     * @param floorId The id of the floor bin.
     * @param activeId The id of the active bin.
     * @param roofId The id of the roof bin.
     * @return totalTokenInPair The amount of tokens that are owned by this contract as liquidity.
     * @return totalWNativeInPair The amount of wNative that are owned by this contract as liquidity.
     * @return sharesLeftSide The amount of shares owned by this contract as liquidity from floor to active bin.
     * @return reservesY The amount of wNative owned by this contract as liquidity.
     */
    function _getAmountsInPair(uint24 floorId, uint24 activeId, uint24 roofId)
        internal
        view
        virtual
        returns (
            uint256 totalTokenInPair,
            uint256 totalWNativeInPair,
            uint256[] memory sharesLeftSide,
            uint256[] memory reservesY
        )
    {
        // Calculate the total number of bins and the number of bins on the left side (from floor to active bin).
        uint256 nbBins = roofId - floorId + 1;
        uint256 nbBinsLeftSide = floorId > activeId ? 0 : activeId - floorId + 1;

        sharesLeftSide = new uint256[](nbBinsLeftSide);
        reservesY = new uint256[](nbBinsLeftSide);

        for (uint256 i; i < nbBins;) {
            uint256 id = floorId + i;

            // Get the amount of shares owned by this contract, the reserves and the total supply of each bin
            uint256 share = _pair.balanceOf(address(this), id);
            (uint256 binReserveX, uint256 binReserveY) = _pair.getBin(uint24(id));
            uint256 totalShares = _pair.totalSupply(id);

            // The check for totalShares is implicit, as `totalShares >= share`
            if (share > 0) {
                // Calculate the amounts of tokens and wNative owned by this contract and that were added as liquidity
                uint256 reserveX = binReserveX > 0 ? share.mulDivRoundDown(binReserveX, totalShares) : 0;
                uint256 reserveY = binReserveY > 0 ? share.mulDivRoundDown(binReserveY, totalShares) : 0;

                // Update the total amounts
                totalTokenInPair += reserveX;
                totalWNativeInPair += reserveY;

                // Update the arrays for the left side
                if (id <= activeId) {
                    sharesLeftSide[i] = share;
                    reservesY[i] = reserveY;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Calculates the new floor id based on the amount of tokens in circulation and the amount of wNative
     * available in the pair contract.
     * @param floorId The id of the floor bin.
     * @param activeId The id of the active bin.
     * @param tokenInCirculation The amount of tokens in circulation.
     * @param wNativeAvailable The amount of wNative available in the pair contract.
     * @param wNativeReserves The amount of wNative owned by this contract as liquidity.
     * @return newFloorId The new floor id.
     */
    function _calculateNewFloorId(
        uint24 floorId,
        uint24 activeId,
        uint256 tokenInCirculation,
        uint256 wNativeAvailable,
        uint256[] memory wNativeReserves
    ) internal view virtual returns (uint24 newFloorId) {
        if (floorId >= activeId) return floorId;

        // Iterate over all the ids from the active bin to the floor bin, in reverse order
        uint256 id = activeId + 1;
        while (id > floorId) {
            // Decrease the id prior to the calculation to avoid having to subtract 1 from the id in the calculations
            unchecked {
                --id;
            }

            // Calculate the price of the bin and get the wNative reserve
            uint256 price = uint24(id).getPriceFromId(_binStep);
            uint256 wNativeReserve = wNativeReserves[id - floorId];

            // Calculate the amount of wNative needed to buy all the tokens in circulation
            uint256 wNativeNeeded = tokenInCirculation.mulShiftRoundUp(price, Constants.SCALE_OFFSET);

            if (wNativeNeeded > wNativeAvailable) {
                // If the amount of wNative needed is greater than the amount of wNative available, we need to
                // keep iterating over the bins
                wNativeAvailable -= wNativeReserve;
                tokenInCirculation -= wNativeReserve.shiftDivRoundDown(Constants.SCALE_OFFSET, price);
            } else {
                // If the amount of wNative needed is lower than the amount of wNative available, we found the
                // new floor id and we can stop iterating
                break;
            }
        }

        // Make sure that the active id is strictly greater than the new floor id.
        // If it is, force it to be the active id minus 1 to make sure we never pay the composition fee as then
        // the constraint on the distribution of the wNative reserves might be broken. `activeId - 1` is at least
        // equal or greater than `floorId` as the first check ensures that `activeId > floorId`
        return activeId > id ? uint24(id) : activeId - 1;
    }

    /**
     * @dev Rebalances the floor by removing the bins that are not needed anymore and adding their wNative
     * reserves to the new floor bin.
     * @return Whether the floor was rebalanced or not.
     */
    function _rebalanceFloor() internal virtual returns (bool) {
        uint24 activeId = _pair.getActiveId();
        uint24 floorId = _floorId;
        uint24 roofId = _roofId;

        // If the floor is already at the active bin minus one or above, no rebalance is needed.
        // We do `floorId + 1` because if the `activeId = floorId + 1`, the rebalance is not doable because
        // of the composition fee, so in order to raise the floor, the activeId has to be at least equal
        // or greater than `floorId + 2`
        if (uint256(floorId) + 1 >= activeId) return false;

        // Get the amounts of tokens and wNative that are in the pair contract, as well as the shares and
        // wNative reserves owned for each bin
        (
            uint256 totalTokenInPair,
            uint256 totalWNativeInPair,
            uint256[] memory shares,
            uint256[] memory wNativeReserves
        ) = _getAmountsInPair(floorId, activeId, roofId);

        // Calculate the amount of tokens in circulation, which is the total supply minus the tokens that are
        // in the pair.
        uint256 tokenInCirculation = totalSupply() - totalTokenInPair;

        // Calculate the new floor id
        uint256 newFloorId =
            _calculateNewFloorId(floorId, activeId, tokenInCirculation, totalWNativeInPair, wNativeReserves);

        // If the new floor id is the same as the current floor id, no rebalance is needed
        if (newFloorId <= floorId) return false;

        // Calculate the number of bins to remove
        uint256 nbBins = newFloorId - floorId;

        // Get the ids of the bins to remove
        uint256[] memory ids = new uint256[](nbBins);
        for (uint256 i; i < nbBins;) {
            ids[i] = floorId + i;

            unchecked {
                ++i;
            }
        }

        // Reduce the length of the shares array to only keep the shares of the bins that will be removed. We already
        // checked that the new floor id is greater than the current floor id, so we know that the length of the shares
        // array is greater than the number of bins to remove, so this is safe to do
        assembly {
            mstore(shares, nbBins)
        }

        // Update the floor id
        _floorId = uint24(newFloorId);

        _safeRebalance(ids, shares, uint24(newFloorId));

        emit FloorRaised(newFloorId);

        return true;
    }

    /**
     * @dev Helper function to rebalance the floor while making sure to not steal any wNative or tokens that was sent
     * by users prior to the rebalance by users, for example during a swap or a liquidity addition.
     * Note: This functions **only** works if the tokenX is this contract and the tokenY is the `_wNative`.
     * @param ids The ids of the bins to burn.
     * @param shares The shares to burn.
     * @param newFloorId The new floor id.
     */
    function _safeRebalance(uint256[] memory ids, uint256[] memory shares, uint24 newFloorId)
        internal
        virtual
        nonReentrant
    {
        // Get the previous reserves of the pair contract
        (uint256 reserveTokenBefore, uint256 reserveWNativeBefore) = _pair.getReserves();

        // Burns the shares and send the wNative to the pair as we will add all the wNative to the new floor bin
        _pair.burn(address(this), address(_pair), ids, shares);

        // Get the current wNative balance of the pair contract (minus the protocol fees)
        (, uint256 wNativeProtocolFees) = _pair.getProtocolFees();
        uint256 wNativeBalanceSubProtocolFees = _wNative.balanceOf(address(_pair)) - wNativeProtocolFees;

        // Get the new reserves of the pair contract
        (uint256 reserveTokenAfter, uint256 reserveWNativeAfter) = _pair.getReserves();

        // Make sure we don't burn any bins greater or equal to the active bin, as this might send some unexpected
        // tokens to the pair contract
        require(reserveTokenAfter == reserveTokenBefore, "FloorToken: token reserve changed");

        // Calculate the delta amounts to get the ratio
        uint256 deltaReserveWNative = reserveWNativeBefore - reserveWNativeAfter;
        uint256 deltaWNativeBalance = wNativeBalanceSubProtocolFees - reserveWNativeAfter;

        // Calculate the distrib, which is 1e18 if no wnative was in the pair contract, and the ratio between the
        // previous wNative balance and the current one otherwise, rounded up. This is done to make sure that the
        // rebalance doesn't steal any wNative that was sent to the pair contract by the users. This works because
        // we only add wNative, so any token that was sent to the pair prior to the rebalance will be sent back
        // to the pair contract after the rebalance. This can't underflow as `deltaWNativeBalance > 0`.
        uint256 distrib = deltaWNativeBalance > deltaReserveWNative
            ? (deltaReserveWNative * Constants.PRECISION + (deltaWNativeBalance - 1)) / deltaWNativeBalance
            : Constants.PRECISION;

        // Encode the liquidity parameters for the new floor bin
        bytes32[] memory liquidityParameters = new bytes32[](1);
        liquidityParameters[0] = LiquidityConfigurations.encodeParams(0, uint64(distrib), newFloorId);

        // Mint the liquidity to the pair contract, any left over will be sent back to the pair contract as
        // this would be user funds (this contains the wNative or the tokens that were sent to the pair contract
        // prior to the rebalance)
        (bytes32 amountsReceived, bytes32 amountsLeft,) = _pair.mint(address(this), liquidityParameters, address(_pair));

        bytes32 amountsAdded = amountsReceived.sub(amountsLeft);
        uint256 wNativeAmount = amountsAdded.decodeY();
        require(
            wNativeAmount == deltaWNativeBalance * distrib / Constants.PRECISION && wNativeAmount >= deltaReserveWNative
                && amountsAdded.decodeX() == 0,
            "FloorToken: broken invariant"
        );
    }

    /**
     * @dev Raises the roof by `nbBins` bins. New tokens will be minted to the pair contract and directly
     * added to new bins that weren't previously in the range.
     * This will revert if the difference between the new roof id and the floor id is greater than the maximum
     * number of bins or if the current active bin is above the current roof id.
     * @param roofId The id of the roof bin.
     * @param floorId The id of the floor bin.
     * @param nbBins The number of bins to raise the roof by.
     */
    function _raiseRoof(uint24 roofId, uint24 floorId, uint24 nbBins) internal virtual nonReentrant {
        require(nbBins > 0, "FloorToken: zero bins");
        require(roofId == 0 || _pair.getActiveId() <= roofId, "FloorToken: active bin above roof");

        // Calculate the next id, if the roof wasn't already raised, the next id will be `floorId`
        uint256 nextId = roofId == 0 ? floorId : roofId + 1;

        // Calculate the new roof id
        uint256 newRoofId = nextId + nbBins - 1;
        require(newRoofId - floorId <= _MAX_NUM_BINS && newRoofId <= type(uint24).max, "FloorToken: new roof too high");

        // Calculate the amount of tokens to mint and the share per bin
        uint64 sharePerBin = uint64(Constants.PRECISION) / nbBins;
        uint256 tokenAmount = _tokenPerBin * nbBins;

        // Encode the liquidity parameters for each bin
        bytes32[] memory liquidityParameters = new bytes32[](nbBins);
        for (uint256 i; i < nbBins;) {
            liquidityParameters[i] = LiquidityConfigurations.encodeParams(sharePerBin, 0, uint24(nextId + i));

            unchecked {
                ++i;
            }
        }

        // Get the current reserves of the pair contract
        (uint256 tokenReserve,) = _pair.getReserves();
        (uint256 tokenProtocolFees,) = _pair.getProtocolFees();

        // Calculate the amount of tokens that are owned by the pair contract as liquidity
        uint256 tokenBalanceSubProtocolFees = balanceOf(address(_pair)) - tokenProtocolFees;

        // Calculate the amount of tokens that were sent to the pair contract waiting to be added as liquidity or
        // swapped for wNative.
        uint256 previousBalance = tokenBalanceSubProtocolFees - tokenReserve;

        // Mint or burn the tokens to make sure that the amount of tokens that will be added as liquidity is
        // exactly `tokenAmount`.
        unchecked {
            if (previousBalance > tokenAmount) _burn(address(_pair), previousBalance - tokenAmount);
            else if (tokenAmount > previousBalance) _mint(address(_pair), tokenAmount - previousBalance);
        }

        // Mint the tokens to the pair contract and mint the liquidity
        (bytes32 amountsReceived, bytes32 amountsLeft,) = _pair.mint(address(this), liquidityParameters, address(_pair));

        // Make sure that no tokens Y were added as liquidity as this would mean stealing user funds.
        require(amountsReceived.sub(amountsLeft).decodeY() == 0, "FloorToken: invalid amounts");

        // Make sure that the amount of tokens X that were added as liquidity is exactly `tokenAmount`
        uint256 tokenLeft;
        if (amountsLeft.decodeX() > 0) {
            (uint256 tokenReserveAfter,) = _pair.getReserves();
            (uint256 tokenProtocolFeesAfter,) = _pair.getProtocolFees();

            // Calculate the amount of tokens that are left from the deposit
            tokenLeft = balanceOf(address(_pair)) - (tokenReserveAfter + tokenProtocolFeesAfter);
        }

        // Mint or burn the token to make sure that the amount of token in excess is exactly `previousBalance`
        unchecked {
            if (tokenLeft > previousBalance) _burn(address(_pair), tokenLeft - previousBalance);
            else if (previousBalance > tokenLeft) _mint(address(_pair), previousBalance - tokenLeft);
        }

        // Update the roof id
        _roofId = uint24(newRoofId);

        emit RoofRaised(newRoofId);
    }

    /**
     * @dev Overrides the `_beforeTokenTransfer` function to rebalance the floor if needed and when possible.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     */
    function _beforeTokenTransfer(address from, address to, uint256) internal virtual {
        // If the token is being transferred from the pair contract, it can't be rebalanced as the
        // reentrancy guard will prevent it
        if (from == address(_pair) || from == address(0) || to == address(0)) return;

        // If the rebalance is not paused, rebalance the floor if needed
        if (!_rebalancePaused && _status == _STATUS_NOT_ENTERED) _rebalanceFloor();
    }

    /**
     * @dev Mint tokens to an account.
     * This function needs to be overriden by the child contract and should not trigger any callback for safety.
     * @param account The address of the account to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function _mint(address account, uint256 amount) internal virtual;

    /**
     * @dev Burn tokens from an account.
     * This function needs to be overriden by the child contract and should not trigger any callback for safety.
     * @param account The address of the account to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address account, uint256 amount) internal virtual;
}
