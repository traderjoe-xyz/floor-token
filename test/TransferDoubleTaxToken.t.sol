// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/math/Math.sol";

import "src/TransferTaxToken.sol";
import "src/TransferDoubleTaxToken.sol";
import "src/presets/TransferDoubleTaxTokenInitialSupply.sol";

contract TransferDoubleTaxTokenTest is Test {
    using Math for uint256;

    TransferDoubleTaxToken public token;

    function setUp() public {
        token = new TransferDoubleTaxToken("Transfer Double Tax Token", "TDTT", address(this));
    }

    function test_NameAndSymbol() public {
        assertEq(token.name(), "Transfer Double Tax Token", "test_NameAndSymbol::1");
        assertEq(token.symbol(), "TDTT", "test_NameAndSymbol::2");
    }

    function test_SupportsInterface() public {
        assertTrue(token.supportsInterface(type(ITransferDoubleTaxToken).interfaceId), "test_SupportsInterface::1");
        assertTrue(token.supportsInterface(type(ITransferTaxToken).interfaceId), "test_SupportsInterface::2");
        assertTrue(token.supportsInterface(type(IERC20).interfaceId), "test_SupportsInterface::3");
        assertTrue(token.supportsInterface(type(IERC165).interfaceId), "test_SupportsInterface::4");
        assertTrue(token.supportsInterface(type(ERC165).interfaceId), "test_SupportsInterface::5");

        assertFalse(token.supportsInterface(bytes4(0xffffffff)), "test_SupportsInterface::6");
        assertFalse(token.supportsInterface(bytes4(0x00000000)), "test_SupportsInterface::7");
    }

    function test_revert_NotOwner(address user) public {
        vm.assume(user != token.owner());

        vm.startPrank(user);

        vm.expectRevert("Ownable: caller is not the owner");
        token.setSecondTaxRecipient(address(1));

        vm.expectRevert("Ownable: caller is not the owner");
        token.setShareForSecondTaxRecipient(1);

        vm.stopPrank();
    }

    function test_MintInitialSupply(address owner, uint256 initialSupply) public {
        vm.assume(owner != address(0));

        token = TransferDoubleTaxToken(
            new TransferDoubleTaxTokenInitialSupply("Transfer Double Tax Token", "TDTT", owner, initialSupply)
        );

        assertEq(token.balanceOf(owner), initialSupply, "test_MintInitialSupply::1");
        assertEq(token.totalSupply(), initialSupply, "test_MintInitialSupply::2");
    }

    function test_SetTaxRecipients() public {
        token.setTaxRecipient(address(1));
        assertEq(token.taxRecipient(), address(1), "test_SetTaxRecipients::1");

        token.setSecondTaxRecipient(address(2));
        assertEq(token.secondTaxRecipient(), address(2), "test_SetTaxRecipients::2");
    }

    function test_SetTaxRecipientsFuzzing(address recipient1, address recipient2) public {
        token.setTaxRecipient(recipient1);
        assertEq(token.taxRecipient(), recipient1, "test_TaxRecipientFuzzing::1");

        token.setSecondTaxRecipient(recipient2);
        assertEq(token.secondTaxRecipient(), recipient2, "test_TaxRecipientFuzzing::2");
    }

    function test_SetTaxRateAndShare() public {
        token.setTaxRate(1);
        assertEq(token.taxRate(), 1, "test_SetTaxRateAndShare::1");

        token.setShareForSecondTaxRecipient(1);
        assertEq(token.shareForSecondTaxRecipient(), 1, "test_SetTaxRateAndShare::2");

        token.setTaxRate(0);
        assertEq(token.taxRate(), 0, "test_SetTaxRateAndShare::3");

        token.setShareForSecondTaxRecipient(0);
        assertEq(token.shareForSecondTaxRecipient(), 0, "test_SetTaxRateAndShare::4");

        token.setTaxRate(1e18);
        assertEq(token.taxRate(), 1e18, "test_SetTaxRateAndShare::5");

        token.setShareForSecondTaxRecipient(1e18);
        assertEq(token.shareForSecondTaxRecipient(), 1e18, "test_SetTaxRateAndShare::6");

        vm.expectRevert("TransferTaxToken: tax rate exceeds 100%");
        token.setTaxRate(1e18 + 1);

        vm.expectRevert("TransferDoubleTaxToken: invalid share");
        token.setShareForSecondTaxRecipient(1e18 + 1);
    }

    function test_SetTaxRateAndShareFuzzing(uint256 rate1, uint256 rate2, uint256 share1, uint256 share2) public {
        rate1 = bound(rate1, 0, 1e18);
        rate2 = bound(rate2, 0, 1e18);

        share1 = bound(share1, 0, 1e18);
        share2 = bound(share2, 0, 1e18);

        token.setTaxRate(rate1);
        assertEq(token.taxRate(), rate1, "test_SetTaxRateAndShareFuzzing::1");

        token.setShareForSecondTaxRecipient(share1);
        assertEq(token.shareForSecondTaxRecipient(), share1, "test_SetTaxRateAndShareFuzzing::2");

        token.setTaxRate(rate2);
        assertEq(token.taxRate(), rate2, "test_SetTaxRateAndShareFuzzing::3");

        token.setShareForSecondTaxRecipient(share2);
        assertEq(token.shareForSecondTaxRecipient(), share2, "test_SetTaxRateAndShareFuzzing::4");

        vm.expectRevert("TransferTaxToken: tax rate exceeds 100%");
        token.setTaxRate(bound(rate1, 1e18 + 1, type(uint256).max));

        vm.expectRevert("TransferDoubleTaxToken: invalid share");
        token.setShareForSecondTaxRecipient(bound(share1, 1e18 + 1, type(uint256).max));
    }

    function test_Transfer() public {
        token.setTaxRecipient(address(this));
        token.setSecondTaxRecipient(address(this));

        token.setTaxRate(0.1e18); // 10%
        token.setShareForSecondTaxRecipient(0.5e18); // 50%

        deal(address(token), address(1), 100);

        vm.prank(address(1));
        token.transfer(address(2), 10);

        assertEq(token.balanceOf(address(1)), 90, "test_Transfer::1");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::2");
        assertEq(token.balanceOf(address(this)), 1, "test_Transfer::3");

        token.setSecondTaxRecipient(address(5));

        vm.prank(address(1));
        token.transfer(address(3), 50);

        assertEq(token.balanceOf(address(1)), 40, "test_Transfer::4");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::5");
        assertEq(token.balanceOf(address(3)), 45, "test_Transfer::6");
        assertEq(token.balanceOf(address(this)), 4, "test_Transfer::7");
        assertEq(token.balanceOf(address(5)), 2, "test_transfer::8");

        token.setExcludedFromTax(address(1), true);

        vm.prank(address(1));
        token.transfer(address(4), 40);

        assertEq(token.balanceOf(address(1)), 0, "test_Transfer::9");
        assertEq(token.balanceOf(address(2)), 9, "test_Transfer::10");
        assertEq(token.balanceOf(address(3)), 45, "test_Transfer::11");
        assertEq(token.balanceOf(address(4)), 40, "test_Transfer::12");
        assertEq(token.balanceOf(address(this)), 4, "test_Transfer::13");
        assertEq(token.balanceOf(address(5)), 2, "test_transfer::14");
    }

    function test_TransferFuzzing(address from, address to, uint256 taxRate, uint256 amount1, uint256 amount2) public {
        vm.assume(
            from != address(0) && to != address(0) && from != to && from != address(this) && to != address(this)
                && from != address(5) && to != address(5)
        );

        taxRate = bound(taxRate, 0, 1e18);

        amount2 = bound(amount2, 0, type(uint256).max - amount1);

        uint256 sum = amount1 + amount2;

        token.setTaxRecipient(address(this));
        token.setSecondTaxRecipient(address(5));

        token.setTaxRate(taxRate);
        token.setShareForSecondTaxRecipient(0.5e18); // 50%

        deal(address(token), from, sum);

        vm.prank(from);
        token.transfer(to, amount1);

        assertEq(token.balanceOf(from), sum - amount1, "test_TransferFuzzing::1");

        uint256 tax1 = amount1.mulDiv(taxRate, 1e18);
        uint256 amountAfterTax1 = amount1 - tax1;

        assertEq(token.balanceOf(to), amountAfterTax1, "test_TransferFuzzing::2");
        assertEq(token.balanceOf(address(this)), tax1 > 0 ? (tax1 - 1) / 2 + 1 : 0, "test_TransferFuzzing::3");
        assertEq(token.balanceOf(address(5)), tax1 / 2, "test_TransferFuzzing::4");

        token.setExcludedFromTax(from, true);

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), 0, "test_TransferFuzzing::5");

        assertEq(token.balanceOf(to), amountAfterTax1 + amount2, "test_TransferFuzzing::6");
        assertEq(token.balanceOf(address(this)), tax1 > 0 ? (tax1 - 1) / 2 + 1 : 0, "test_TransferFuzzing::7");
        assertEq(token.balanceOf(address(5)), tax1 / 2, "test_TransferFuzzing::8");
    }

    function test_TransferAndBurn() public {
        token.setTaxRecipient(address(this));
        token.setTaxRate(0.1e18); // 10%
        token.setShareForSecondTaxRecipient(0.5e18); // 50%

        deal(address(token), address(1), 100, true);

        vm.prank(address(1));
        token.transfer(address(2), 20);

        assertEq(token.balanceOf(address(1)), 80, "test_TransferAndBurn::1");
        assertEq(token.balanceOf(address(2)), 18, "test_TransferAndBurn::2");
        assertEq(token.balanceOf(address(this)), 1, "test_TransferAndBurn::3");
        assertEq(token.totalSupply(), 99, "test_TransferAndBurn::4");

        token.setTaxRecipient(address(0));
        token.setSecondTaxRecipient(address(this));

        token.setTaxRate(0.5e18); // 50%
        token.setShareForSecondTaxRecipient(0.5e18); // 50%

        vm.prank(address(1));
        token.transfer(address(3), 40);

        assertEq(token.balanceOf(address(1)), 40, "test_TransferAndBurn::5");
        assertEq(token.balanceOf(address(2)), 18, "test_TransferAndBurn::6");
        assertEq(token.balanceOf(address(3)), 20, "test_TransferAndBurn::7");
        assertEq(token.balanceOf(address(this)), 11, "test_TransferAndBurn::8");
        assertEq(token.totalSupply(), 89, "test_TransferAndBurn::9");

        token.setExcludedFromTax(address(1), true);

        vm.prank(address(1));
        token.transfer(address(4), 40);

        assertEq(token.balanceOf(address(1)), 0, "test_TransferAndBurn::10");
        assertEq(token.balanceOf(address(2)), 18, "test_TransferAndBurn::11");
        assertEq(token.balanceOf(address(3)), 20, "test_TransferAndBurn::12");
        assertEq(token.balanceOf(address(this)), 11, "test_TransferAndBurn::13");
        assertEq(token.totalSupply(), 89, "test_TransferAndBurn::14");
    }

    function testFuzzing_TransferAndBurn(
        address from,
        address to,
        uint256 taxRate,
        uint256 share,
        uint256 amount1,
        uint256 amount2
    ) public {
        vm.assume(from != address(0) && to != address(0) && from != to && from != address(this) && to != address(this));

        taxRate = bound(taxRate, 0, 1e18);
        share = bound(share, 0, 1e18);

        amount2 = bound(amount2, 0, type(uint256).max - amount1);

        uint256 sum = amount1 + amount2;

        token.setTaxRecipient(address(this));
        token.setSecondTaxRecipient(address(0));

        token.setTaxRate(taxRate);
        token.setShareForSecondTaxRecipient(share);

        deal(address(token), from, sum, true);

        vm.prank(from);
        token.transfer(to, amount1);

        assertEq(token.balanceOf(from), sum - amount1, "testFuzzing_TransferAndBurn::1");

        (uint256 tax1_1, uint256 tax1_2, uint256 amountAfterTax1) = (0, 0, 0);

        {
            uint256 totalTax1 = amount1.mulDiv(taxRate, 1e18);

            tax1_2 = totalTax1.mulDiv(share, 1e18);
            tax1_1 = totalTax1 - tax1_2;

            amountAfterTax1 = amount1 - totalTax1;
        }

        assertEq(token.balanceOf(to), amountAfterTax1, "testFuzzing_TransferAndBurn::2");
        assertEq(token.balanceOf(address(this)), tax1_1, "testFuzzing_TransferAndBurn::3");
        assertEq(token.totalSupply(), sum - tax1_2, "testFuzzing_TransferAndBurn::4");

        token.setTaxRecipient(address(0));
        token.setSecondTaxRecipient(address(this));

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), sum - amount1 - amount2, "testFuzzing_TransferAndBurn::5");

        (uint256 tax2_1, uint256 tax2_2, uint256 amountAfterTax2) = (0, 0, 0);

        {
            uint256 totalTax2 = amount2.mulDiv(taxRate, 1e18);

            tax2_2 = totalTax2.mulDiv(share, 1e18);
            tax2_1 = totalTax2 - tax2_2;

            amountAfterTax2 = amount2 - totalTax2;
        }

        assertEq(token.balanceOf(to), amountAfterTax1 + amountAfterTax2, "testFuzzing_TransferAndBurn::6");
        assertEq(token.balanceOf(address(this)), tax1_1 + tax2_2, "testFuzzing_TransferAndBurn::7");
        assertEq(token.totalSupply(), sum - tax1_2 - tax2_1, "testFuzzing_TransferAndBurn::8");
    }
}
