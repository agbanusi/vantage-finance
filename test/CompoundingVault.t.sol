// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/CompoundingTokenVault.sol";
import "../src/Vault.sol";
import {MockERC20, MockWETH} from "./MockToken.sol";
import {MockProvider} from "./MockProvider.sol";


// =================================================================
// Tests for CompoundingTokenVault
// =================================================================
contract CompoundingTokenVaultTest is Test {
    CompoundingTokenVault vault;
    MockERC20 token;
    MockProvider provider1;
    MockProvider provider2;
    address owner = address(1);
    uint256 initialBalance = 1000 ether;

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20("Test Token", "TTK");
        token.mint(owner, initialBalance);

        // Deploy the compounding vault.
        vault = new CompoundingTokenVault(owner, address(0), address(0), address(0));
        
        // Deploy two providers and add them.
        provider1 = new MockProvider();
        provider2 = new MockProvider();
        vault.addProvider(address(provider1));
        vault.addProvider(address(provider2));

        // Approve and deposit tokens into the vault.
        token.approve(address(vault), initialBalance);
        uint256 lockDuration = block.timestamp + 1 days;
        vault.deposit(address(token), 100 ether, lockDuration);
        vm.stopPrank();
    }

    // Test compoundInvestment by simulating rewards.
    function testCompoundInvestment() public {
        vm.startPrank(owner);
        // Simulate rewards for each provider.
        uint256 rewardAmount1 = 10 ether;
        uint256 rewardAmount2 = 20 ether;
        token.mint(address(provider1), rewardAmount1);
        token.mint(address(provider2), rewardAmount2);
        provider1.setExtraReward(rewardAmount1);
        provider2.setExtraReward(rewardAmount2);

        uint256 initialVaultBalance = token.balanceOf(address(vault));
        vault.compoundInvestment(address(token));
        uint256 totalRewards = rewardAmount1 + rewardAmount2;
        uint256 finalVaultBalance = token.balanceOf(address(vault));
        // The vault should pull in and redeposit the rewards.
        assertEq(finalVaultBalance, initialVaultBalance - totalRewards);
        vm.stopPrank();
    }
}
