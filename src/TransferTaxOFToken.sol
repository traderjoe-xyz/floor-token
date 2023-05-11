// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OFTCore, Ownable, IOFTCore} from "layerzero/token/oft/OFTCore.sol";

import {TransferTaxToken, Ownable2Step, IERC165} from "./TransferTaxToken.sol";
import {ITransferTaxOFToken} from "./interfaces/ITransferTaxOFToken.sol";

/**
 * @title Transfer Tax Omnichain Fungible Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipient and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 * The owner can mint tokens to any account.
 * The token is also an OFT token, the tax isn't applied to OFT transfers.
 */
contract TransferTaxOFToken is OFTCore, TransferTaxToken, ITransferTaxOFToken {
    /**
     * @notice Constructor that initializes the token's name, symbol, initial supply and the OFT endpoint.
     * @dev The token is minted to the `owner`.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param initialSupply The initial supply of the token.
     * @param owner The owner of the token.
     * @param lzEndpoint The OFT endpoint.
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply, address owner, address lzEndpoint)
        TransferTaxToken(name, symbol, initialSupply, owner)
        OFTCore(lzEndpoint)
    {}

    /**
     * @notice Returns true if the `interfaceId` is supported by this contract.
     * @param interfaceId The interface identifier.
     * @return True if the `interfaceId` is supported by this contract.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(TransferTaxToken, OFTCore, IERC165)
        returns (bool)
    {
        return interfaceId == type(IOFTCore).interfaceId || TransferTaxToken.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the address of the ERC20 token, which is the address of this contract.
     * @return The address of the token.
     */
    function token() public view virtual override returns (address) {
        return address(this);
    }

    /**
     * @notice Returns the circulating supply of the token on the current chain.
     * @return The circulating supply of the token on the current chain.
     */
    function circulatingSupply() public view virtual override returns (uint256) {
        return totalSupply();
    }

    /**
     * @notice Starts the ownership transfer of the contract to a new account.
     * Replaces the pending owner if there is one.
     * @dev Can only be called by the current owner.
     * Overrides the `transferOwnership` function as both the `Ownable` and `Ownable2Step` contracts define it.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) public virtual override(Ownable2Step, Ownable) {
        Ownable2Step.transferOwnership(newOwner);
    }

    /**
     * @notice Debits `amount` from `from`.
     * @param from The address to debit from.
     * @param amount The amount to debit and credit.
     * @return The amount credited to `to`.
     */
    function _debitFrom(address from, uint16, bytes memory, uint256 amount)
        internal
        virtual
        override
        returns (uint256)
    {
        address spender = _msgSender();
        if (from != spender) _spendAllowance(from, spender, amount);
        _burn(from, amount);
        return amount;
    }

    /**
     * @notice Credits `amount` to `toAddress`.
     * @param toAddress The address to credit to.
     * @param amount The amount to credit.
     * @return The amount credited to `toAddress`.
     */
    function _creditTo(uint16, address toAddress, uint256 amount) internal virtual override returns (uint256) {
        _mint(toAddress, amount);
        return amount;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     * Overrides the `_transferOwnership` function as both the `Ownable` and `Ownable2Step` contracts define it.
     * @param newOwner The address of the new owner.
     */
    function _transferOwnership(address newOwner) internal virtual override(Ownable2Step, Ownable) {
        Ownable2Step._transferOwnership(newOwner);
    }
}
