// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IOFTCore} from "layerzero/token/oft/IOFTCore.sol";

import {ITransferTaxToken} from "./ITransferTaxToken.sol";

interface ITransferTaxOFToken is ITransferTaxToken, IOFTCore {}
