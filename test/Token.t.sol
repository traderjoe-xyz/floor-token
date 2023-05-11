// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/Token.sol";

contract TokenTest is Test {
    Token public token;

    function setUp() public {
        token = new Token();
    }

    function testMint() public {
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
    }
}
