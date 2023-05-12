// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/TransferTaxToken.sol";
import "src/TransferTaxOFToken.sol";
import "src/presets/TransferTaxOFTokenInitialSupply.sol";
import "layerzero/mocks/LZEndpointMock.sol";

contract TransferTaxOFTokenTest is Test {
    uint16 public constant CHAIN_ID_1 = 1;
    LZEndpointMock public endpoint1;
    TransferTaxOFTokenInitialSupply public token1;

    uint16 public constant CHAIN_ID_2 = 2;
    LZEndpointMock public endpoint2;
    TransferTaxOFToken public token2;

    uint256 globalSupply = 100e18;
    address payable owner = payable(makeAddr("owner"));

    function setUp() public {
        endpoint1 = new LZEndpointMock(CHAIN_ID_1);
        endpoint2 = new LZEndpointMock(CHAIN_ID_2);

        vm.deal(owner, 100e18);

        vm.startPrank(owner);

        token1 =
        new TransferTaxOFTokenInitialSupply("Transfer Tax OF Token", "TTOFT", owner, globalSupply, address(endpoint1));
        token2 = new TransferTaxOFToken("Transfer Tax OF Token", "TTOFT", owner, address(endpoint2));

        endpoint1.setDestLzEndpoint(address(token2), address(endpoint2));
        endpoint2.setDestLzEndpoint(address(token1), address(endpoint1));

        bytes memory path2to1 = abi.encodePacked(token2, token1);
        bytes memory path1to2 = abi.encodePacked(token1, token2);

        token1.setTrustedRemote(CHAIN_ID_2, path2to1);
        token2.setTrustedRemote(CHAIN_ID_1, path1to2);

        token1.setMinDstGas(CHAIN_ID_2, token1.PT_SEND(), 220000);
        token2.setMinDstGas(CHAIN_ID_1, token1.PT_SEND(), 220000);

        token1.setUseCustomAdapterParams(true);
        token2.setUseCustomAdapterParams(true);

        vm.stopPrank();
    }

    function test_SupportsInterface() public {
        assertTrue(token1.supportsInterface(type(IOFTCore).interfaceId), "test_SupportsInterface::1");
        assertTrue(token1.supportsInterface(type(IERC20).interfaceId), "test_SupportsInterface::2");
        assertTrue(token1.supportsInterface(type(IERC165).interfaceId), "test_SupportsInterface::3");
        assertTrue(token1.supportsInterface(type(ERC165).interfaceId), "test_SupportsInterface::4");

        assertFalse(token1.supportsInterface(bytes4(0xffffffff)), "test_SupportsInterface::5");
        assertFalse(token1.supportsInterface(bytes4(0x00000000)), "test_SupportsInterface::6");
    }

    function test_Token() public {
        assertEq(token1.token(), address(token1), "test_Token::1");
        assertEq(token2.token(), address(token2), "test_Token::2");
    }

    function test_CirculatingSupply() public {
        assertEq(token1.circulatingSupply(), globalSupply, "test_CirculatingSupply::1");
        assertEq(token2.circulatingSupply(), 0, "test_CirculatingSupply::2");
    }

    function test_TransferOwnership() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(1));
        token1.transferOwnership(address(1));

        vm.startPrank(owner);

        token1.transferOwnership(address(this));
        assertEq(token1.pendingOwner(), address(this), "test_TransferOwnership::1");
        assertEq(token1.owner(), owner, "test_TransferOwnership::2");

        vm.expectRevert("Ownable2Step: caller is not the new owner");
        token1.acceptOwnership();

        vm.stopPrank();

        vm.prank(address(this));
        token1.acceptOwnership();

        assertEq(token1.owner(), address(this), "test_TransferOwnership::3");
        assertEq(token1.pendingOwner(), address(0), "test_TransferOwnership::4");
    }

    function test_TransferFrom1to2And2to1() public {
        bytes memory adapterParam = abi.encodePacked(uint16(1), uint256(225000));
        uint256 sendQty = 1e18;

        (uint256 nativeFee,) = token1.estimateSendFee(CHAIN_ID_2, abi.encodePacked(owner), sendQty, false, adapterParam);

        vm.prank(owner);
        token1.sendFrom{value: nativeFee}(
            owner, CHAIN_ID_2, abi.encodePacked(owner), sendQty, owner, address(0), adapterParam
        );

        assertEq(token1.balanceOf(owner), globalSupply - sendQty, "test_TransferFrom1to2::1");
        assertEq(token2.balanceOf(owner), sendQty, "test_TransferFrom1to2::2");

        assertEq(token1.circulatingSupply(), globalSupply - sendQty, "test_TransferFrom1to2::3");
        assertEq(token2.circulatingSupply(), sendQty, "test_TransferFrom1to2::4");

        uint256 sendBackQty = 0.9e18;

        (nativeFee,) = token2.estimateSendFee(CHAIN_ID_1, abi.encodePacked(owner), sendBackQty, false, adapterParam);

        vm.prank(owner);
        token2.sendFrom{value: nativeFee}(
            owner, CHAIN_ID_1, abi.encodePacked(owner), sendBackQty, owner, address(0), adapterParam
        );

        assertEq(token2.balanceOf(owner), sendQty - sendBackQty, "test_TransferFrom1to2::5");
        assertEq(token1.balanceOf(owner), globalSupply - sendQty + sendBackQty, "test_TransferFrom1to2::6");

        assertEq(token1.circulatingSupply(), globalSupply - sendQty + sendBackQty, "test_TransferFrom1to2::7");
        assertEq(token2.circulatingSupply(), sendQty - sendBackQty, "test_TransferFrom1to2::8");
    }
}
