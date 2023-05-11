// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20PresetFixedSupply, IERC20} from "openzeppelin-contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {ERC165} from "openzeppelin-contracts/utils/introspection/ERC165.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {ITransferTaxToken, IERC165} from "./interfaces/ITransferTaxToken.sol";

/**
 * @title Transfer Tax Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipient and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 * The owner can mint tokens to any account.
 */
contract TransferTaxToken is ERC20PresetFixedSupply, Ownable2Step, ERC165, ITransferTaxToken {
    using Math for uint256;

    uint256 internal constant _PRECISION = 1e18;

    /**
     * @dev The recipient and rate of the transfer tax.
     */
    address private _taxRecipient;
    uint96 private _taxRate;

    /**
     * @dev The exclusion status of accounts from transfer tax.
     */
    mapping(address => bool) private _excludedFromTax;

    /**
     * @notice Constructor that initializes the token's name, symbol and initial supply.
     * @dev The token is minted to the `owner`.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param initialSupply The initial supply of the token.
     * @param owner The owner of the token.
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply, address owner)
        ERC20PresetFixedSupply(name, symbol, initialSupply, owner)
    {
        _transferOwnership(owner);
    }

    /**
     * @notice Returns the address of the transfer tax recipient.
     * @return The address of the transfer tax recipient.
     */
    function taxRecipient() public view virtual override returns (address) {
        return _taxRecipient;
    }

    /**
     * @notice Returns the transfer tax rate.
     * @return The transfer tax rate.
     */
    function taxRate() public view virtual override returns (uint256) {
        return _taxRate;
    }

    /**
     * @notice Returns true if the `interfaceId` is supported by this contract.
     * @param interfaceId The interface identifier.
     * @return True if the `interfaceId` is supported by this contract.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ITransferTaxToken).interfaceId || interfaceId == type(IERC20).interfaceId
            || ERC165.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns true if `account` is excluded from transfer tax.
     * @param account The account to check.
     * @return True if `account` is excluded from transfer tax.
     */
    function excludedFromTax(address account) public view virtual override returns (bool) {
        return _excludedFromTax[account];
    }

    /**
     * @notice Set the transfer tax recipient to `newTaxRecipient`.
     * @dev Only callable by the owner.
     * @param newTaxRecipient The new transfer tax recipient.
     */
    function setTaxRecipient(address newTaxRecipient) public virtual override onlyOwner {
        _setTaxRecipient(newTaxRecipient);
    }

    /**
     * @notice Set the transfer tax rate to `newTaxRate`.
     * @dev Only callable by the owner. The tax recipient must be set before setting the tax rate.
     * The tax rate must be less than or equal to 100% (1e18).
     * @param newTaxRate The new transfer tax rate.
     */
    function setTaxRate(uint256 newTaxRate) public virtual override onlyOwner {
        _setTaxRate(newTaxRate);
    }

    /**
     * @notice Set `excluded` as the exclusion status of `account` from transfer tax.
     * @dev Only callable by the owner.
     * @param account The account to set exclusion status for.
     * @param excluded The exclusion status to set.
     */
    function setExcludedFromTax(address account, bool excluded) public virtual override onlyOwner {
        _setExcludedFromTax(account, excluded);
    }

    /**
     * @dev Set the transfer tax recipient to `newTaxRecipient`.
     * @param newTaxRecipient The new transfer tax recipient.
     */
    function _setTaxRecipient(address newTaxRecipient) internal virtual {
        require(newTaxRecipient != address(0), "TransferTaxToken: zero address");

        _taxRecipient = newTaxRecipient;

        emit TaxRecipientSet(newTaxRecipient);
    }

    /**
     * @dev Set the transfer tax rate to `newTaxRate`.
     * @param newTaxRate The new transfer tax rate.
     */
    function _setTaxRate(uint256 newTaxRate) internal virtual {
        require(_taxRecipient != address(0), "TransferTaxToken: tax recipient not set");
        require(newTaxRate <= _PRECISION, "TransferTaxToken: tax rate exceeds 100%");

        // SafeCast is not needed here since the tax rate is bound by PRECISION, which is strictly less than 2**96.
        _taxRate = uint96(newTaxRate);

        emit TaxRateSet(newTaxRate);
    }

    /**
     * @dev Set `excluded` as the exclusion status of `account` from transfer tax.
     * @param account The account to set exclusion status for.
     * @param excluded The exclusion status to set.
     */
    function _setExcludedFromTax(address account, bool excluded) internal virtual {
        require(_excludedFromTax[account] != excluded, "TransferTaxToken: same exclusion status");

        _excludedFromTax[account] = excluded;

        emit ExcludedFromTaxSet(account, excluded);
    }

    /**
     * @dev Transfer `amount` tokens from `sender` to `recipient`.
     * Overrides ERC20's transfer function to include transfer tax.
     * @param sender The sender address.
     * @param recipient The recipient address.
     * @param amount The amount to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        if (amount > 0) {
            if (_excludedFromTax[sender] || _excludedFromTax[recipient]) {
                super._transfer(sender, recipient, amount);
            } else {
                uint256 taxAmount = amount.mulDiv(_taxRate, _PRECISION);
                uint256 amountAfterTax = amount - taxAmount;

                if (taxAmount > 0) super._transfer(sender, _taxRecipient, taxAmount);
                if (amountAfterTax > 0) super._transfer(sender, recipient, amountAfterTax);
            }
        }
    }
}
