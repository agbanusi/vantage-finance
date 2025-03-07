// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/TokenVault.sol"; // adjust the path as needed
import {MockERC20, MockWETH} from "./MockToken.sol";
import {MockProvider} from "./MockProvider.sol";


// =================================================================
// TestTokenVault extends TokenVault to allow setting the WETH address
// =================================================================
contract TestTokenVault is TokenVault {
    constructor(
        address _owner,
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        TokenVault(_owner, _wormholeRelayer, _tokenBridge, _wormhole)
    {}

    // Setter so we can initialize WETH for testing
    function setWETH(address _weth) external onlyOwner {
        weth = IERC20(_weth);
    }
}

// =================================================================
// Comprehensive Forge tests for TokenVault
// =================================================================
contract TokenVaultTest is Test {
    TestTokenVault vault;
    MockERC20 token;
    MockProvider provider1;
    MockProvider provider2;
    MockWETH weth;
    address owner = address(100);
    address user = address(101);
    uint256 initialBalance = 1000 ether;

    // For signature testing – an arbitrary private key and its address.
    uint256 userPrivateKey = 0xA11CE;
    address userSigner;

    function setUp() public {
        vm.startPrank(owner);
        // Deploy a mock token and mint tokens to owner and user
        token = new MockERC20("Test Token", "TTK");
        token.mint(owner, initialBalance);
        token.mint(user, initialBalance);

        // Deploy mock WETH contract
        weth = new MockWETH();

        // Deploy the vault (note: wormhole parameters are set to address(0) for testing)
        vault = new TestTokenVault(owner, address(0), address(0), address(0));
        // Set the WETH address so that receive() works properly
        vault.setWETH(address(weth));

        // Deploy two mock providers and add them to the vault
        provider1 = new MockProvider();
        provider2 = new MockProvider();
        vault.addProvider(address(provider1));
        vault.addProvider(address(provider2));
        vm.stopPrank();

        // Setup a user account for signature tests
        userSigner = vm.addr(userPrivateKey);
        // (In a real scenario, userSigner should equal user if you wish to test withdrawal for that account.)
    }

    // -----------------------------------------------------
    // Test provider management: add and remove provider.
    // -----------------------------------------------------
    function testAddAndRemoveProvider() public {
        vm.startPrank(owner);
        // Deploy a new provider and add it
        MockProvider provider3 = new MockProvider();
        vault.addProvider(address(provider3));

        // Removing provider3 should succeed (its removal is what we expect)
        vault.removeProvider(address(provider3));
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test token deposit via the deposit() function.
    // -----------------------------------------------------
    function testDepositToken() public {
        vm.startPrank(owner);
        uint256 depositAmount = 100 ether;
        // Set a lock duration in the future
        uint256 lockDuration = block.timestamp + 1 days;

        // Approve the vault to spend tokens on behalf of owner
        token.approve(address(vault), depositAmount);
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vault.deposit(address(token), depositAmount, lockDuration);

        // Check that the deposit record was updated
        (uint256 depositedAmount,,,,,,) = vault.userDeposits(owner, address(token));
        assertEq(depositedAmount, depositAmount);

        // Since there are 2 providers, the deposit should be split evenly.
        uint256 expectedShare = depositAmount / 2;
        // In our MockProvider, the deposit function transfers tokens from the vault.
        uint256 prov1Balance = token.balanceOf(address(provider1));
        uint256 prov2Balance = token.balanceOf(address(provider2));
        assertEq(prov1Balance, expectedShare);
        assertEq(prov2Balance, expectedShare);

        // Owner’s balance should have decreased by depositAmount.
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter, ownerBalanceBefore - depositAmount);
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test Ether deposit via the receive() function.
    // -----------------------------------------------------
    function testDepositEther() public {
        vm.startPrank(user);
        uint256 depositAmount = 10 ether;
        // Send Ether to the vault (this triggers the receive() function)
        (bool success, ) = address(vault).call{value: depositAmount}("");
        require(success, "Ether deposit failed");

        // Check that the user’s deposit record for WETH was updated
        (uint256 depositedAmount,,,,,,) = vault.userDeposits(user, address(weth));
        assertEq(depositedAmount, depositAmount);
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test changing the lock duration.
    // -----------------------------------------------------
    function testChangeLockDuration() public {
        vm.startPrank(owner);
        uint256 depositAmount = 50 ether;
        uint256 initialLock = block.timestamp + 1 days;
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount, initialLock);

        // Change lock duration to a new time in the future
        uint256 newLock = block.timestamp + 2 days;
        vault.changeLockDuration(address(token), newLock);

        (, uint256 lockDuration,,,,,) = vault.userDeposits(owner, address(token));
        // The contract adds the _lockDuration to the current lock, so the expected value is:
        // previous lockDuration + (newLock - current time)
        uint256 expectedLock = initialLock + (newLock - block.timestamp);
        assertEq(lockDuration, expectedLock);
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test token withdrawal via withdraw()
    // -----------------------------------------------------
    function testWithdrawToken() public {
        vm.startPrank(owner);
        uint256 depositAmount = 100 ether;
        uint256 lockTime = block.timestamp + 1 days;
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount, lockTime);

        // Fast forward time past the lock duration
        vm.warp(lockTime + 1);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 withdrawAmount = depositAmount / 2;
        vault.withdraw(address(token), withdrawAmount);

        // Check that the deposit record is updated correctly
        (uint256 remaining,,,,,,) = vault.userDeposits(owner, address(token));
        assertEq(remaining, depositAmount - withdrawAmount);

        // Owner’s token balance should have increased by the withdrawn amount
        uint256 ownerBalanceAfter = token.balanceOf(owner);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + withdrawAmount);
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test token withdrawal using a valid signature.
    // -----------------------------------------------------
    function testWithdrawWithSignature() public {
        // For this test, we simulate a deposit by "user" and then have the vault
        // process a withdrawal for the user using a signature.
        vm.startPrank(owner);
        uint256 depositAmount = 100 ether;
        uint256 lockTime = block.timestamp + 1 days;
        token.approve(address(vault), depositAmount);
        // For simplicity, deposit under owner then simulate a transfer to user deposit.
        vault.deposit(address(token), depositAmount, lockTime);
        vm.stopPrank();

        // (For testing purposes, assume the user deposit is recorded in vault.userDeposits(user, token))
        // In real use, the deposit might be done by the user directly.
        // Fast forward time past the lock period.
        vm.warp(lockTime + 1);

        // Create the message hash as used in withdrawWithSignature:
        // message = keccak256(abi.encodePacked(_user, _tokenAddress, _amount))
        uint256 withdrawAmount = 50 ether;
        bytes32 message = keccak256(abi.encodePacked(user, address(token), withdrawAmount));
        // Then the contract wraps it with the Ethereum signed message header.
        bytes32 ethSignedMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        // Use cheatcode to sign the message with userPrivateKey
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, ethSignedMessage);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(owner);
        // Process the withdrawal on behalf of user
        vault.withdrawWithSignature(user, address(token), withdrawAmount, signature);

        // Check that the deposit for the user has decreased.
        (, uint256 remaining,,,,,) = vault.userDeposits(user, address(token));
        // For this test, we assume the user’s deposit was set equal to depositAmount.
        assertEq(remaining, depositAmount - withdrawAmount);
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test the rebalance functionality.
    // -----------------------------------------------------
    function testRebalance() public {
        vm.startPrank(owner);
        // Deposit tokens from owner
        uint256 depositAmount = 200 ether;
        uint256 lockTime = block.timestamp + 1 days;
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount, lockTime);

        // Call rebalance – it withdraws all tokens from every provider and then
        // distributes them evenly among active providers.
        vault.rebalance(address(token));

        // Check that providers now hold nearly equal amounts.
        uint256 tvl1 = provider1.balances(address(token));
        uint256 tvl2 = provider2.balances(address(token));
        // Allow a difference of 1 unit (due to integer division)
        assertApproxEqAbs(tvl1, tvl2, 1);
        vm.stopPrank();
    }

    // -----------------------------------------------------
    // Test clearing stuck funds.
    // -----------------------------------------------------
    function testClearStuckFunds() public {
        vm.startPrank(owner);
        // Transfer tokens directly to the vault (simulate stuck funds)
        token.transfer(address(vault), 10 ether);
        uint256 vaultBalance = token.balanceOf(address(vault));
        assertEq(vaultBalance, 10 ether);

        // Clear funds by sending them to owner
        vault.clearStuckFunds(address(token), owner);
        uint256 ownerBalance = token.balanceOf(owner);
        // Owner should now have their original balance plus the cleared funds.
        assertEq(ownerBalance, initialBalance + 10 ether);
        vm.stopPrank();
    }
}
