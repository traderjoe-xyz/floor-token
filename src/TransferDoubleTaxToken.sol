// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {TransferTaxToken} from "./TransferTaxToken.sol";
import {ITransferDoubleTaxToken, IERC165} from "./interfaces/ITransferDoubleTaxToken.sol";

/**
 * @title Transfer Double Tax Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipients and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 * The second recipient will receive fees according to the share set by the owner.
 */
contract TransferDoubleTaxToken is TransferTaxToken, ITransferDoubleTaxToken {
    using Math for uint256;

    /**
     * @dev The second recipient and the share of the transfer tax for the second recipient.
     */
    address private _secondTaxRecipient;
    uint96 private _shareForSecondTaxRecipient;

    /**
     * @notice Constructor that initializes the token's name and symbol.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param owner The owner of the token.
     */
    constructor(string memory name, string memory symbol, address owner) TransferTaxToken(name, symbol, owner) {}

    /**
     * @notice Returns the address of the second transfer tax recipient.
     * @return The address of the second transfer tax recipient.
     */
    function secondTaxRecipient() public view virtual override returns (address) {
        return _secondTaxRecipient;
    }

    /**
     * @notice Returns the share of the transfer tax for the second recipient.
     * @return The share of the transfer tax for the second recipient.
     */
    function shareForSecondTaxRecipient() public view virtual override returns (uint256) {
        return _shareForSecondTaxRecipient;
    }

    /**
     * @notice Returns true if the `interfaceId` is supported by this contract.
     * @param interfaceId The interface identifier.
     * @return True if the `interfaceId` is supported by this contract.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(TransferTaxToken, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(ITransferDoubleTaxToken).interfaceId || TransferTaxToken.supportsInterface(interfaceId);
    }

    /**
     * @notice Sets the second transfer tax recipient.
     * @dev Only callable by the owner.
     * @param newSecondTaxRecipient The new second transfer tax recipient.
     */
    function setSecondTaxRecipient(address newSecondTaxRecipient) public override onlyOwner {
        _secondTaxRecipient = newSecondTaxRecipient;

        emit SecondTaxRecipientSet(newSecondTaxRecipient);
    }

    /**
     * @notice Sets the share of the transfer tax for the second recipient.
     * @dev Only callable by the owner.
     * @param newShareForSecondRecipient The new share of the transfer tax for the second recipient.
     */
    function setShareForSecondTaxRecipient(uint256 newShareForSecondRecipient) public override onlyOwner {
        require(newShareForSecondRecipient <= _PRECISION, "TransferDoubleTaxToken: invalid share");

        _shareForSecondTaxRecipient = uint96(newShareForSecondRecipient);

        emit ShareForSecondTaxRecipientSet(newShareForSecondRecipient);
    }

    /**
     * @notice Overrides the parent `_transferTaxAmount` function to split the tax between the two recipients.
     * @param sender The sender of the tokens.
     * @param firstTaxRecipient The first recipient of the tokens.
     * @param totalTaxAmount The total tax amount that will be split between the two tax recipients.
     */
    function _transferTaxAmount(address sender, address firstTaxRecipient, uint256 totalTaxAmount)
        internal
        virtual
        override
    {
        address secondTaxRecipient_ = secondTaxRecipient();

        if (secondTaxRecipient_ != firstTaxRecipient) {
            uint256 amountForSecondTaxRecipient = totalTaxAmount.mulDiv(shareForSecondTaxRecipient(), _PRECISION);

            totalTaxAmount -= amountForSecondTaxRecipient;

            super._transferTaxAmount(sender, secondTaxRecipient_, amountForSecondTaxRecipient);
        }

        super._transferTaxAmount(sender, firstTaxRecipient, totalTaxAmount);
    }
}
