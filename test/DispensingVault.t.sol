// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/DispensingVault.sol";
import "../src/Vault.sol";
import {MockERC20, MockWETH} from "./MockToken.sol";
import {MockProvider} from "./MockProvider.sol";


// =================================================================
// Tests for DispensingTokenVault
// =================================================================
contract DispensingTokenVaultTest is Test {
    DispensingTokenVault vault;
    MockERC20 token;
    MockProvider provider1;
    MockProvider provider2;
    address owner = address(2);
    uint256 initialBalance = 1000 ether;

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20("Test Token", "TTK");
        token.mint(owner, initialBalance);

        // Deploy the dispensing vault.
        vault = new DispensingTokenVault(owner, address(0), address(0), address(0));
        
        // Deploy two providers and add them.
        provider1 = new MockProvider();
        provider2 = new MockProvider();
        vault.addProvider(address(provider1));
        vault.addProvider(address(provider2));

        // Approve and deposit tokens with dispensing parameters.
        token.approve(address(vault), initialBalance);
        uint256 lockDuration = block.timestamp + 1 days;
        uint256 amountToDispense = 10 ether;
        uint256 dispensingPeriod = 1 days;
        vault.deposit(address(token), 100 ether, lockDuration, amountToDispense, dispensingPeriod);
        vm.stopPrank();
    }

    // Test updating dispensing settings.
    function testChangeDispensingSetting() public {
        vm.startPrank(owner);
        uint256 newDispensingPeriod = 2 days;
        uint16 newPercentage = 50000; // e.g. 50% mode.
        uint256 newAmountToDispense = 5 ether;
        // Change dispensing settings: switching to percentage mode (amountDispenser = false).
        vault.changeDispensingSetting(address(token), false, newDispensingPeriod, newPercentage, newAmountToDispense);

        (
            uint256 depositedAmount,
            uint256 lockDuration,
            uint256 dispensingPeriod,
            bool amountDispenser,
            uint16 percentageToDispense,
            uint256 amountToDispense,
            uint256 lastDispensedTime
        ) = vault.userDeposits(owner, address(token));
        assertEq(dispensingPeriod, newDispensingPeriod);
        assertEq(uint256(percentageToDispense), uint256(newPercentage));
        assertEq(amountToDispense, newAmountToDispense);
        assertTrue(amountDispenser == false);
        vm.stopPrank();
    }

    // Test dispenseFund after the dispensing period has elapsed.
    function testDispenseFund() public {
        vm.startPrank(owner);
        (, , uint256 dispensingPeriod, , , uint256 amountToDispense, ) = vault.userDeposits(owner, address(token));
        vm.warp(block.timestamp + dispensingPeriod + 1);

        (uint256 depositAmount, , , , , , ) = vault.userDeposits(owner, address(token));
        uint256 vaultBalanceBefore = token.balanceOf(address(vault));
        vault.dispenseFund(address(token));

        (uint256 newDepositAmount, , , , , , ) = vault.userDeposits(owner, address(token));
        assertEq(newDepositAmount, depositAmount - amountToDispense);

        // Owner should receive dispensed tokens.
        uint256 ownerBalance = token.balanceOf(owner);
        assertEq(ownerBalance, amountToDispense);
        vm.stopPrank();
    }
}
