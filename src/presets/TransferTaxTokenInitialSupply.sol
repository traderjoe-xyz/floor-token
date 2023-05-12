// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TransferTaxToken} from "../TransferTaxToken.sol";

/**
 * @title Transfer Tax Token
 * @author Trader Joe
 * @notice An ERC20 token that has a transfer tax.
 * The tax is calculated as `amount * taxRate / PRECISION`, where `PRECISION = 1e18`.
 * The tax is deducted from the amount before the transfer and sent to the tax recipient.
 * The tax recipient and tax rate can be changed by the owner, as well as the exclusion status of accounts from tax.
 * The token will mint the initial supply to the owner.
 */
contract TransferTaxTokenInitialSupply is TransferTaxToken {
    /**
     * @notice Constructor that initializes the token's name, symbol and initial supply.
     * @dev The token is minted to the `owner`.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param owner The owner of the token.
     * @param initialSupply The initial supply of the token.
     */
    constructor(string memory name, string memory symbol, address owner, uint256 initialSupply)
        TransferTaxToken(name, symbol, owner)
    {
        _mint(owner, initialSupply);
    }
}
