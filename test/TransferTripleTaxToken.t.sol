// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/math/Math.sol";

import "src/TransferTaxToken.sol";
import "src/TransferDoubleTaxToken.sol";
import "src/TransferTripleTaxToken.sol";
import "src/presets/TransferTripleTaxTokenInitialSupply.sol";

contract TransferTripleTaxTokenTest is Test {
    using Math for uint256;

    TransferTripleTaxToken public token;

    function setUp() public {
        token = new TransferTripleTaxToken("Transfer Double Tax Token", "TDTT", address(this));
    }

    function test_NameAndSymbol() public {
        assertEq(token.name(), "Transfer Double Tax Token", "test_NameAndSymbol::1");
        assertEq(token.symbol(), "TDTT", "test_NameAndSymbol::2");
    }

    function test_SupportsInterface() public {
        assertTrue(token.supportsInterface(type(ITransferTripleTaxToken).interfaceId), "test_SupportsInterface::1");
        assertTrue(token.supportsInterface(type(ITransferDoubleTaxToken).interfaceId), "test_SupportsInterface::2");
        assertTrue(token.supportsInterface(type(ITransferTaxToken).interfaceId), "test_SupportsInterface::3");
        assertTrue(token.supportsInterface(type(IERC20).interfaceId), "test_SupportsInterface::4");
        assertTrue(token.supportsInterface(type(IERC165).interfaceId), "test_SupportsInterface::5");
        assertTrue(token.supportsInterface(type(ERC165).interfaceId), "test_SupportsInterface::6");

        assertFalse(token.supportsInterface(bytes4(0xffffffff)), "test_SupportsInterface::7");
        assertFalse(token.supportsInterface(bytes4(0x00000000)), "test_SupportsInterface::8");
    }

    function test_revert_NotOwner(address user) public {
        vm.assume(user != token.owner());

        vm.startPrank(user);

        vm.expectRevert("Ownable: caller is not the owner");
        token.setThirdTaxRecipient(address(1));

        vm.expectRevert("Ownable: caller is not the owner");
        token.setShareForSecondTaxRecipient(1);

        vm.expectRevert("Ownable: caller is not the owner");
        token.setShareForThirdTaxRecipient(1);

        vm.stopPrank();
    }

    function test_MintInitialSupply(address owner, uint256 initialSupply) public {
        vm.assume(owner != address(0));

        token = TransferTripleTaxToken(
            new TransferTripleTaxTokenInitialSupply("Transfer Double Tax Token", "TDTT", owner, initialSupply)
        );

        assertEq(token.balanceOf(owner), initialSupply, "test_MintInitialSupply::1");
        assertEq(token.totalSupply(), initialSupply, "test_MintInitialSupply::2");
    }

    function test_SetTaxRecipients() public {
        token.setTaxRecipient(address(1));
        assertEq(token.taxRecipient(), address(1), "test_SetTaxRecipients::1");

        token.setSecondTaxRecipient(address(2));
        assertEq(token.secondTaxRecipient(), address(2), "test_SetTaxRecipients::2");

        token.setThirdTaxRecipient(address(3));
        assertEq(token.thirdTaxRecipient(), address(3), "test_SetTaxRecipients::3");
    }

    function test_SetTaxRecipientsFuzzing(address recipient1, address recipient2, address recipient3) public {
        token.setTaxRecipient(recipient1);
        assertEq(token.taxRecipient(), recipient1, "test_SetTaxRecipientsFuzzing::1");

        token.setSecondTaxRecipient(recipient2);
        assertEq(token.secondTaxRecipient(), recipient2, "test_SetTaxRecipientsFuzzing::2");

        token.setThirdTaxRecipient(recipient3);
        assertEq(token.thirdTaxRecipient(), recipient3, "test_SetTaxRecipientsFuzzing::3");
    }

    function test_SetTaxRateAndShare() public {
        token.setShareForSecondTaxRecipient(1);
        assertEq(token.shareForSecondTaxRecipient(), 1, "test_SetTaxRateAndShare::1");

        token.setShareForThirdTaxRecipient(1);
        assertEq(token.shareForThirdTaxRecipient(), 1, "test_SetTaxRateAndShare::2");

        token.setShareForSecondTaxRecipient(0);
        assertEq(token.shareForSecondTaxRecipient(), 0, "test_SetTaxRateAndShare::3");

        token.setShareForThirdTaxRecipient(0);
        assertEq(token.shareForThirdTaxRecipient(), 0, "test_SetTaxRateAndShare::4");

        token.setShareForSecondTaxRecipient(1e18);
        assertEq(token.shareForSecondTaxRecipient(), 1e18, "test_SetTaxRateAndShare::5");

        vm.expectRevert("TransferTripleTaxToken: invalid share");
        token.setShareForThirdTaxRecipient(1);

        token.setShareForSecondTaxRecipient(0);

        token.setShareForThirdTaxRecipient(1e18);

        vm.expectRevert("TransferTripleTaxToken: invalid share");
        token.setShareForSecondTaxRecipient(1);
    }

    function test_SetTaxRateAndShareFuzzing(uint256 share1, uint256 share2) public {
        share1 = bound(share1, 0, 1e18);
        share2 = bound(share2, 0, 1e18 - share1);

        token.setShareForSecondTaxRecipient(share1);
        assertEq(token.shareForSecondTaxRecipient(), share1, "test_SetTaxRateAndShareFuzzing::1");

        token.setShareForThirdTaxRecipient(share2);
        assertEq(token.shareForThirdTaxRecipient(), share2, "test_SetTaxRateAndShareFuzzing::2");

        token.setShareForSecondTaxRecipient(0);
        token.setShareForThirdTaxRecipient(0);

        token.setShareForThirdTaxRecipient(share2);
        assertEq(token.shareForThirdTaxRecipient(), share2, "test_SetTaxRateAndShareFuzzing::3");

        token.setShareForSecondTaxRecipient(share1);
        assertEq(token.shareForSecondTaxRecipient(), share1, "test_SetTaxRateAndShareFuzzing::4");

        vm.expectRevert("TransferTripleTaxToken: invalid share");
        token.setShareForSecondTaxRecipient(bound(share1, 1e18 + 1 - share2, type(uint256).max));

        vm.expectRevert("TransferTripleTaxToken: invalid share");
        token.setShareForThirdTaxRecipient(bound(share2, 1e18 + 1 - share1, type(uint256).max));
    }

    function test_Transfer() public {
        token.setTaxRecipient(address(this));
        token.setSecondTaxRecipient(address(10));
        token.setThirdTaxRecipient(address(11));

        token.setTaxRate(0.1e18); // 10%
        token.setShareForSecondTaxRecipient(0.3e18); // 30%
        token.setShareForThirdTaxRecipient(0.2e18); // 20%

        deal(address(token), address(1), 1000);

        vm.prank(address(1));
        token.transfer(address(2), 100);

        assertEq(token.balanceOf(address(1)), 900, "test_Transfer::1");
        assertEq(token.balanceOf(address(2)), 90, "test_Transfer::2");
        assertEq(token.balanceOf(address(this)), 5, "test_Transfer::3");
        assertEq(token.balanceOf(address(10)), 3, "test_Transfer::4");
        assertEq(token.balanceOf(address(11)), 2, "test_Transfer::5");

        token.setExcludedFromTax(address(1), 3);

        vm.prank(address(1));
        token.transfer(address(3), 400);

        assertEq(token.balanceOf(address(1)), 500, "test_Transfer::6");
        assertEq(token.balanceOf(address(2)), 90, "test_Transfer::7");
        assertEq(token.balanceOf(address(3)), 400, "test_Transfer::8");
        assertEq(token.balanceOf(address(this)), 5, "test_Transfer::9");
        assertEq(token.balanceOf(address(10)), 3, "test_Transfer::10");
        assertEq(token.balanceOf(address(11)), 2, "test_Transfer::11");
    }

    function test_TransferFuzzing(
        address from,
        address to,
        uint256 taxRate,
        uint256 share1,
        uint256 share2,
        uint256 amount1,
        uint256 amount2
    ) public {
        vm.assume(
            from != address(0) && to != address(0) && from != to && from != address(this) && to != address(this)
                && from != address(1) && to != address(1) && from != address(2) && to != address(2)
        );

        taxRate = bound(taxRate, 0, 1e18);

        share1 = bound(share1, 0, 1e18);
        share2 = bound(share2, 0, 1e18 - share1);

        amount2 = bound(amount2, 0, type(uint256).max - amount1);

        uint256 sum = amount1 + amount2;

        token.setTaxRecipient(address(this));

        token.setSecondTaxRecipient(address(1));
        token.setThirdTaxRecipient(address(2));

        token.setTaxRate(taxRate);

        token.setShareForSecondTaxRecipient(share1);
        token.setShareForThirdTaxRecipient(share2);

        deal(address(token), from, sum);

        vm.prank(from);
        token.transfer(to, amount1);

        assertEq(token.balanceOf(from), sum - amount1, "test_TransferFuzzing::1");

        uint256 totalTaxAmount = amount1.mulDiv(taxRate, 1e18);
        uint256 amount1AfterTax = amount1 - totalTaxAmount;

        assertEq(token.balanceOf(to), amount1AfterTax, "test_TransferFuzzing::2");

        uint256 tax1 = totalTaxAmount.mulDiv(share1, 1e18);
        uint256 tax2 = totalTaxAmount.mulDiv(share2, 1e18);
        totalTaxAmount -= tax1 + tax2;

        assertEq(token.balanceOf(address(this)), totalTaxAmount, "test_TransferFuzzing::3");
        assertEq(token.balanceOf(address(1)), tax1, "test_TransferFuzzing::4");
        assertEq(token.balanceOf(address(2)), tax2, "test_TransferFuzzing::5");

        token.setExcludedFromTax(from, 3);

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), 0, "test_TransferFuzzing::6");

        assertEq(token.balanceOf(to), amount1AfterTax + amount2, "test_TransferFuzzing::7");
        assertEq(token.balanceOf(address(this)), totalTaxAmount, "test_TransferFuzzing::8");
        assertEq(token.balanceOf(address(1)), tax1, "test_TransferFuzzing::9");
        assertEq(token.balanceOf(address(2)), tax2, "test_TransferFuzzing::10");
    }

    function test_TransferAndBurn() public {
        token.setTaxRecipient(address(this));
        token.setTaxRate(0.1e18); // 10%
        token.setShareForSecondTaxRecipient(0.5e18); // 50%
        token.setShareForThirdTaxRecipient(0.1e18); // 10%

        deal(address(token), address(1), 1000, true);

        vm.prank(address(1));
        token.transfer(address(2), 100);

        assertEq(token.balanceOf(address(1)), 900, "test_TransferAndBurn::1");
        assertEq(token.balanceOf(address(2)), 90, "test_TransferAndBurn::2");
        assertEq(token.balanceOf(address(this)), 4, "test_TransferAndBurn::3");
        assertEq(token.totalSupply(), 994, "test_TransferAndBurn::4");

        token.setTaxRecipient(address(0));
        token.setSecondTaxRecipient(address(this));

        vm.prank(address(1));
        token.transfer(address(3), 100);

        assertEq(token.balanceOf(address(1)), 800, "test_TransferAndBurn::5");
        assertEq(token.balanceOf(address(2)), 90, "test_TransferAndBurn::6");
        assertEq(token.balanceOf(address(3)), 90, "test_TransferAndBurn::7");
        assertEq(token.balanceOf(address(this)), 9, "test_TransferAndBurn::8");
        assertEq(token.totalSupply(), 989, "test_TransferAndBurn::9");

        token.setSecondTaxRecipient(address(0));
        token.setThirdTaxRecipient(address(this));

        token.setShareForSecondTaxRecipient(0.9e18);

        vm.prank(address(1));
        token.transfer(address(4), 800);

        assertEq(token.balanceOf(address(1)), 0, "test_TransferAndBurn::10");
        assertEq(token.balanceOf(address(2)), 90, "test_TransferAndBurn::11");
        assertEq(token.balanceOf(address(3)), 90, "test_TransferAndBurn::12");
        assertEq(token.balanceOf(address(4)), 720, "test_TransferAndBurn::13");
        assertEq(token.balanceOf(address(this)), 17, "test_TransferAndBurn::14");
        assertEq(token.totalSupply(), 917, "test_TransferAndBurn::15");
    }

    function testFuzzing_TransferAndBurn(
        address from,
        address to,
        uint256 taxRate,
        uint256 share1,
        uint256 share2,
        uint256 amount1,
        uint256 amount2
    ) public {
        vm.assume(
            from != address(0) && to != address(0) && from != to && from != address(this) && to != address(this)
                && from != address(1) && to != address(1)
        );

        taxRate = bound(taxRate, 0, 1e18);

        share1 = bound(share1, 0, 1e18);
        share2 = bound(share2, 0, 1e18 - share1);

        amount2 = bound(amount2, 0, type(uint256).max - amount1);

        uint256 sum = bound(amount1 + amount2, amount1 + amount2, type(uint256).max);

        token.setTaxRecipient(address(this));

        token.setSecondTaxRecipient(address(0));
        token.setThirdTaxRecipient(address(1));

        token.setTaxRate(taxRate);

        token.setShareForSecondTaxRecipient(share1);
        token.setShareForThirdTaxRecipient(share2);

        deal(address(token), from, sum, true);

        vm.prank(from);
        token.transfer(to, amount1);

        assertEq(token.balanceOf(from), sum - amount1, "testFuzzing_TransferAndBurn::1");

        (uint256 taxForThis, uint256 taxBurn, uint256 taxFor1, uint256 amountAfterTax1) = (0, 0, 0, 0);

        {
            uint256 totalTax1 = amount1.mulDiv(taxRate, 1e18);

            taxBurn = totalTax1.mulDiv(share1, 1e18);
            taxFor1 = totalTax1.mulDiv(share2, 1e18);
            taxForThis = totalTax1 - taxBurn - taxFor1;

            amountAfterTax1 = amount1 - totalTax1;
        }

        assertEq(token.balanceOf(to), amountAfterTax1, "testFuzzing_TransferAndBurn::2");
        assertEq(token.balanceOf(address(this)), taxForThis, "testFuzzing_TransferAndBurn::3");
        assertEq(token.balanceOf(address(1)), taxFor1, "testFuzzing_TransferAndBurn::4");
        assertEq(token.totalSupply(), sum - taxBurn, "testFuzzing_TransferAndBurn::5");

        token.setTaxRecipient(address(0));
        token.setSecondTaxRecipient(address(this));

        vm.prank(from);
        token.transfer(to, amount2);

        assertEq(token.balanceOf(from), sum - amount1 - amount2, "testFuzzing_TransferAndBurn::6");

        uint256 amountAfterTax2;

        {
            uint256 totalTax2 = amount2.mulDiv(taxRate, 1e18);

            uint256 tax2_2 = totalTax2.mulDiv(share1, 1e18);
            uint256 tax2_3 = totalTax2.mulDiv(share2, 1e18);
            uint256 tax2_1 = totalTax2 - tax2_2 - tax2_3;

            taxBurn += tax2_1;
            taxForThis += tax2_2;
            taxFor1 += tax2_3;

            amountAfterTax2 = amount2 - totalTax2;
        }

        assertEq(token.balanceOf(to), amountAfterTax1 + amountAfterTax2, "testFuzzing_TransferAndBurn::7");
        assertEq(token.balanceOf(address(this)), taxForThis, "testFuzzing_TransferAndBurn::8");
        assertEq(token.balanceOf(address(1)), taxFor1, "testFuzzing_TransferAndBurn::9");
        assertEq(token.totalSupply(), sum - taxBurn, "testFuzzing_TransferAndBurn::10");
    }
}
