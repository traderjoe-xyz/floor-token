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
        token.setExcludedFromTax(address(1), 0);

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
    }

    function test_SetTaxRecipientFuzzing(address recipient1, address recipient2) public {
        token.setTaxRecipient(recipient1);
        assertEq(token.taxRecipient(), recipient1, "test_SetTaxRecipientFuzzing::1");

        token.setTaxRecipient(recipient2);
        assertEq(token.taxRecipient(), recipient2, "test_SetTaxRecipientFuzzing::2");
    }

    function test_SetTaxRate() public {
        token.setTaxRate(1);
        assertEq(token.taxRate(), 1, "test_SetTaxRate::1");

        token.setTaxRate(0);
        assertEq(token.taxRate(), 0, "test_SetTaxRate::2");

        token.setTaxRate(1e18);
        assertEq(token.taxRate(), 1e18, "test_SetTaxRate::3");

        vm.expectRevert("TransferTaxToken: tax rate exceeds 100%");
        token.setTaxRate(1e18 + 1);
    }

    function test_SetTaxRateFuzzing(uint256 rate1, uint256 rate2) public {
        rate1 = bound(rate1, 0, 1e18);
        rate2 = bound(rate2, 0, 1e18);

        token.setTaxRate(rate1);
        assertEq(token.taxRate(), rate1, "test_SetTaxRateFuzzing::1");

        token.setTaxRate(rate2);
        assertEq(token.taxRate(), rate2, "test_SetTaxRateFuzzing::2");

        vm.expectRevert("TransferTaxToken: tax rate exceeds 100%");
        token.setTaxRate(bound(rate1, 1e18 + 1, type(uint256).max));
    }

    function test_SetExcludedFromTax() public {
        token.setExcludedFromTax(address(1), 1);
        assertEq(token.excludedFromTax(address(1)), 1, "test_SetExcludedFromTax::1");

        token.setExcludedFromTax(address(1), 2);
        assertEq(token.excludedFromTax(address(1)), 2, "test_SetExcludedFromTax::2");

        token.setExcludedFromTax(address(this), 3);
        assertEq(token.excludedFromTax(address(this)), 3, "test_SetExcludedFromTax::3");

        token.setExcludedFromTax(address(this), 0);
        assertEq(token.excludedFromTax(address(this)), 0, "test_SetExcludedFromTax::4");

        vm.expectRevert("TransferTaxToken: same exclusion status");
        token.setExcludedFromTax(address(this), 0);

        vm.expectRevert("TransferTaxToken: invalid excluded status");
        token.setExcludedFromTax(address(this), 4);
    }

    function test_SetExcludedFromTaxFuzzing(address account1, uint256 status) public {
        status = bound(status, 1, 3);

        vm.expectRevert("TransferTaxToken: same exclusion status");
        token.setExcludedFromTax(account1, 0);

        token.setExcludedFromTax(account1, status);

        assertEq(token.excludedFromTax(account1), status, "test_SetExcludedFromTaxFuzzing::1");

        vm.expectRevert("TransferTaxToken: same exclusion status");
        token.setExcludedFromTax(account1, status);

        token.setExcludedFromTax(account1, 0);

        assertEq(token.excludedFromTax(account1), 0, "test_SetExcludedFromTaxFuzzing::2");

        vm.expectRevert("TransferTaxToken: invalid excluded status");
        token.setExcludedFromTax(account1, bound(status, 4, type(uint256).max));
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

        token.setExcludedFromTax(address(1), 1); // Only from

        vm.prank(address(1));
        token.transfer(address(3), 10);

        assertEq(token.balanceOf(address(1)), 80, "test_Transfer::4");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::5");
        assertEq(token.balanceOf(address(3)), 10, "test_Transfer::6");
        assertEq(token.balanceOf(address(this)), 1, "test_Transfer::7");

        token.setExcludedFromTax(address(1), 2); // Only to

        vm.prank(address(1));
        token.transfer(address(4), 10);

        assertEq(token.balanceOf(address(1)), 70, "test_Transfer::8");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::9");
        assertEq(token.balanceOf(address(3)), 10, "test_Transfer::10");
        assertEq(token.balanceOf(address(4)), 9, "test_Transfer::11");
        assertEq(token.balanceOf(address(this)), 2, "test_Transfer::12");

        vm.prank(address(3));
        token.transfer(address(1), 10);

        assertEq(token.balanceOf(address(1)), 80, "test_Transfer::13");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::14");
        assertEq(token.balanceOf(address(3)), 0, "test_Transfer::15");
        assertEq(token.balanceOf(address(4)), 9, "test_Transfer::16");
        assertEq(token.balanceOf(address(this)), 2, "test_Transfer::17");

        token.setExcludedFromTax(address(1), 3); // Both

        vm.prank(address(1));
        token.transfer(address(5), 10);

        assertEq(token.balanceOf(address(1)), 70, "test_Transfer::18");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::19");
        assertEq(token.balanceOf(address(3)), 0, "test_Transfer::20");
        assertEq(token.balanceOf(address(4)), 9, "test_Transfer::21");
        assertEq(token.balanceOf(address(5)), 10, "test_Transfer::22");
        assertEq(token.balanceOf(address(this)), 2, "test_Transfer::23");

        vm.prank(address(5));
        token.transfer(address(1), 10);

        assertEq(token.balanceOf(address(1)), 80, "test_Transfer::24");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::25");
        assertEq(token.balanceOf(address(3)), 0, "test_Transfer::26");
        assertEq(token.balanceOf(address(4)), 9, "test_Transfer::27");
        assertEq(token.balanceOf(address(5)), 0, "test_Transfer::28");
        assertEq(token.balanceOf(address(this)), 2, "test_Transfer::29");
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

        assertEq(token.balanceOf(to), amountAfterTax1, "test_TransferFuzzing::2");
        assertEq(token.balanceOf(address(this)), tax1, "test_TransferFuzzing::3");

        token.setExcludedFromTax(from, 1); // Only from

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), 0, "test_TransferFuzzing::4");

        assertEq(token.balanceOf(to), amountAfterTax1 + amount2, "test_TransferFuzzing::5");
        assertEq(token.balanceOf(address(this)), tax1, "test_TransferFuzzing::6");

        token.setExcludedFromTax(from, 2); // Only to

        vm.prank(to);
        token.transfer(from, amount2);

        assertEq(token.balanceOf(from), amount2, "test_TransferFuzzing::7");

        assertEq(token.balanceOf(to), amountAfterTax1, "test_TransferFuzzing::8");
        assertEq(token.balanceOf(address(this)), tax1, "test_TransferFuzzing::9");
    }

    function test_TransferAndBurn() public {
        token.setTaxRate(0.1e18); // 10%

        deal(address(token), address(1), 100, true);

        vm.prank(address(1));
        token.transfer(address(2), 10);

        assertEq(token.balanceOf(address(1)), 90, "test_TransferAndBurn::1");
        assertEq(token.balanceOf(address(2)), 9, "test_TransferAndBurn::2");
        assertEq(token.totalSupply(), 99, "test_TransferAndBurn::3");

        token.setExcludedFromTax(address(1), 3);

        vm.prank(address(1));
        token.transfer(address(3), 90);

        assertEq(token.balanceOf(address(1)), 0, "test_TransferAndBurn::4");
        assertEq(token.balanceOf(address(2)), 9, "test_TransferAndBurn::5");
        assertEq(token.balanceOf(address(3)), 90, "test_TransferAndBurn::6");
        assertEq(token.totalSupply(), 99, "test_TransferAndBurn::7");
    }

    function testFuzzing_TransferAndBurn(address from, address to, uint256 taxRate, uint256 amount1, uint256 amount2)
        public
    {
        vm.assume(from != address(0) && to != address(0) && from != to && from != address(this) && to != address(this));

        taxRate = bound(taxRate, 0, 1e18);

        amount2 = bound(amount2, 0, type(uint256).max - amount1);

        uint256 sum = amount1 + amount2;

        token.setTaxRate(taxRate);

        deal(address(token), from, sum, true);

        vm.prank(from);
        token.transfer(to, amount1);

        assertEq(token.balanceOf(from), sum - amount1, "testFuzzing_TransferAndBurn::1");

        uint256 tax1 = amount1.mulDiv(taxRate, 1e18);
        uint256 amountAfterTax1 = amount1 - tax1;

        assertEq(token.balanceOf(to), amountAfterTax1, "testFuzzing_TransferAndBurn::2");
        assertEq(token.totalSupply(), sum - tax1, "testFuzzing_TransferAndBurn::3");

        token.setExcludedFromTax(from, 3);

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), 0, "testFuzzing_TransferAndBurn::4");

        assertEq(token.balanceOf(to), amountAfterTax1 + amount2, "testFuzzing_TransferAndBurn::5");
        assertEq(token.totalSupply(), sum - tax1, "testFuzzing_TransferAndBurn::6");
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
