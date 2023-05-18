// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/math/Math.sol";

import "src/TransferTaxToken.sol";
import "src/presets/TransferTaxTokenInitialSupply.sol";

contract TransferTaxTokenTest is Test {
    using Math for uint256;

    TransferTaxToken public token;

    function setUp() public {
        token = new TransferTaxToken("Transfer Tax Token", "TTT", address(this));
    }

    function test_NameAndSymbol() public {
        assertEq(token.name(), "Transfer Tax Token", "test_NameAndSymbol::1");
        assertEq(token.symbol(), "TTT", "test_NameAndSymbol::2");
    }

    function test_SupportsInterface() public {
        assertTrue(token.supportsInterface(type(ITransferTaxToken).interfaceId), "test_SupportsInterface::1");
        assertTrue(token.supportsInterface(type(IERC20).interfaceId), "test_SupportsInterface::2");
        assertTrue(token.supportsInterface(type(IERC165).interfaceId), "test_SupportsInterface::3");
        assertTrue(token.supportsInterface(type(ERC165).interfaceId), "test_SupportsInterface::4");

        assertFalse(token.supportsInterface(bytes4(0xffffffff)), "test_SupportsInterface::5");
        assertFalse(token.supportsInterface(bytes4(0x00000000)), "test_SupportsInterface::6");
    }

    function test_revert_NotOwner(address user) public {
        vm.assume(user != token.owner());

        vm.startPrank(user);

        vm.expectRevert("Ownable: caller is not the owner");
        token.setTaxRecipient(address(1));

        vm.expectRevert("Ownable: caller is not the owner");
        token.setTaxRate(1);

        vm.expectRevert("Ownable: caller is not the owner");
        token.setExcludedFromTax(address(1), true);

        vm.stopPrank();
    }

    function test_MintInitialSupply(address owner, uint256 initialSupply) public {
        vm.assume(owner != address(0));

        token = TransferTaxToken(new TransferTaxTokenInitialSupply("Transfer Tax Token", "TTT", owner, initialSupply));

        assertEq(token.balanceOf(owner), initialSupply, "test_MintInitialSupply::1");
        assertEq(token.totalSupply(), initialSupply, "test_MintInitialSupply::2");
    }

    function test_SetTaxRecipient() public {
        token.setTaxRecipient(address(1));
        assertEq(token.taxRecipient(), address(1), "test_SetTaxRecipient::1");

        token.setTaxRecipient(address(this));
        assertEq(token.taxRecipient(), address(this), "test_SetTaxRecipient::2");

        vm.expectRevert("TransferTaxToken: zero address");
        token.setTaxRecipient(address(0));
    }

    function test_SetTaxRecipientFuzzing(address recipient1, address recipient2) public {
        vm.assume(recipient1 != address(0) && recipient2 != address(0));

        token.setTaxRecipient(recipient1);
        assertEq(token.taxRecipient(), recipient1, "test_TaxRecipient::1");

        token.setTaxRecipient(recipient2);
        assertEq(token.taxRecipient(), recipient2, "test_TaxRecipient::2");
    }

    function test_SetTaxRate() public {
        vm.expectRevert("TransferTaxToken: tax recipient not set");
        token.setTaxRate(1);

        token.setTaxRecipient(address(this));

        token.setTaxRate(1);
        assertEq(token.taxRate(), 1, "test_TaxRate::1");

        token.setTaxRate(0);
        assertEq(token.taxRate(), 0, "test_TaxRate::2");

        token.setTaxRate(1e18);
        assertEq(token.taxRate(), 1e18, "test_TaxRate::3");

        vm.expectRevert("TransferTaxToken: tax rate exceeds 100%");
        token.setTaxRate(1e18 + 1);
    }

    function test_SetTaxRateFuzzing(uint256 rate1, uint256 rate2) public {
        rate1 = bound(rate1, 0, 1e18);
        rate2 = bound(rate2, 0, 1e18);

        vm.expectRevert("TransferTaxToken: tax recipient not set");
        token.setTaxRate(rate1);

        token.setTaxRecipient(address(this));

        token.setTaxRate(rate1);
        assertEq(token.taxRate(), rate1, "test_TaxRate::1");

        token.setTaxRate(rate2);
        assertEq(token.taxRate(), rate2, "test_TaxRate::2");

        vm.expectRevert("TransferTaxToken: tax rate exceeds 100%");
        token.setTaxRate(bound(rate1, 1e18 + 1, type(uint256).max));
    }

    function test_SetExcludedFromTax() public {
        token.setExcludedFromTax(address(1), true);
        assertEq(token.excludedFromTax(address(1)), true, "test_SetExcludedFromTax::1");

        token.setExcludedFromTax(address(1), false);
        assertEq(token.excludedFromTax(address(1)), false, "test_SetExcludedFromTax::2");

        token.setExcludedFromTax(address(this), true);
        assertEq(token.excludedFromTax(address(this)), true, "test_SetExcludedFromTax::3");

        token.setExcludedFromTax(address(this), false);
        assertEq(token.excludedFromTax(address(this)), false, "test_SetExcludedFromTax::4");

        vm.expectRevert("TransferTaxToken: same exclusion status");
        token.setExcludedFromTax(address(this), false);
    }

    function test_SetExcludedFromTaxFuzzing(address account1) public {
        vm.expectRevert("TransferTaxToken: same exclusion status");
        token.setExcludedFromTax(account1, false);

        token.setExcludedFromTax(account1, true);

        assertTrue(token.excludedFromTax(account1), "test_SetExcludedFromTaxFuzzing::1");

        vm.expectRevert("TransferTaxToken: same exclusion status");
        token.setExcludedFromTax(account1, true);

        token.setExcludedFromTax(account1, false);

        assertFalse(token.excludedFromTax(account1), "test_SetExcludedFromTaxFuzzing::2");
    }

    function test_Transfer() public {
        token.setTaxRecipient(address(this));
        token.setTaxRate(0.1e18); // 10%

        deal(address(token), address(1), 100);

        vm.prank(address(1));
        token.transfer(address(2), 10);

        assertEq(token.balanceOf(address(1)), 90, "test_Transfer::1");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::2");
        assertEq(token.balanceOf(address(this)), 1, "test_Transfer::3");

        token.setExcludedFromTax(address(1), true);

        vm.prank(address(1));
        token.transfer(address(3), 90);

        assertEq(token.balanceOf(address(1)), 0, "test_Transfer::4");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::5");
        assertEq(token.balanceOf(address(3)), 90, "test_Transfer::6");
        assertEq(token.balanceOf(address(this)), 1, "test_Transfer::7");
    }

    function test_TransferFuzzing(address from, address to, uint256 taxRate, uint256 amount1, uint256 amount2) public {
        vm.assume(from != address(0) && to != address(0) && from != to && from != address(this) && to != address(this));

        taxRate = bound(taxRate, 0, 1e18);

        amount2 = bound(amount2, 0, type(uint256).max - amount1);

        uint256 sum = amount1 + amount2;

        token.setTaxRecipient(address(this));
        token.setTaxRate(taxRate);

        deal(address(token), from, sum);

        vm.prank(from);
        token.transfer(to, amount1);

        assertEq(token.balanceOf(from), sum - amount1, "test_TransferFuzzing::1");

        uint256 tax1 = amount1.mulDiv(taxRate, 1e18);
        uint256 amountAfterTax1 = amount1 - tax1;

        assertEq(token.balanceOf(to), amountAfterTax1, "test_Transfer::2");
        assertEq(token.balanceOf(address(this)), tax1, "test_Transfer::3");

        token.setExcludedFromTax(from, true);

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), 0, "test_TransferFuzzing::4");

        assertEq(token.balanceOf(to), amountAfterTax1 + amount2, "test_TransferFuzzing::5");
        assertEq(token.balanceOf(address(this)), tax1, "test_TransferFuzzing::6");
    }

    function test_SelfTransferNoTax() public {
        token.setTaxRecipient(address(this));
        token.setTaxRate(1e18); // 100%

        deal(address(token), address(1), 100);

        vm.prank(address(1));
        token.transfer(address(1), 100);

        assertEq(token.balanceOf(address(1)), 100, "test_SelfTransferNoTax::1");
        assertEq(token.balanceOf(address(this)), 0, "test_SelfTransferNoTax::2");

        vm.prank(address(1));
        token.transfer(address(2), 100);

        assertEq(token.balanceOf(address(1)), 0, "test_SelfTransferNoTax::3");
        assertEq(token.balanceOf(address(2)), 0, "test_SelfTransferNoTax::4");
        assertEq(token.balanceOf(address(this)), 100, "test_SelfTransferNoTax::5");
    }
}
