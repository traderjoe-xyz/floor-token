// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TransferTaxOFToken} from "../TransferTaxOFToken.sol";

/**
 * @title Transfer Tax Omnichain Fungible Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipient and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 * The token is also an OFT token, the tax isn't applied to OFT transfers.
 * The token will mint the initial supply to the owner.
 */
contract TransferTaxOFTokenInitialSupply is TransferTaxOFToken {
    /**
     * @notice Constructor that initializes the token's name, symbol, initial supply and the OFT endpoint.
     * @dev The token is minted to the `owner`.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param owner The owner of the token.
     * @param initialSupply The initial supply of the token.
     * @param lzEndpoint The OFT endpoint.
     */
    constructor(string memory name, string memory symbol, address owner, uint256 initialSupply, address lzEndpoint)
        TransferTaxOFToken(name, symbol, owner, lzEndpoint)
    {
        _mint(owner, initialSupply);
    }
}
