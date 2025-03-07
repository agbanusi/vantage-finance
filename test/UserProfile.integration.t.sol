// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/UserProfile.sol";

/// @dev A test version of UserProfile that exposes _handle for integration testing.
contract TestUserProfileIntegration is UserProfile {
    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) UserProfile(_wormholeRelayer, _tokenBridge, _wormhole) {}

    // Expose _handle so we can simulate receipt of a cross-chain payload.
    function testHandlePublic(address recipient, bytes memory message) external {
        _handle(recipient, message);
    }

    // Helper to manually set the global profile "active" flag.
    function setUserActive(address _user, bool _active) external {
        UserData memory data = userData[_user];
        data.active = _active;
        userData[_user] = data;
    }
}

contract UserProfile_IntegrationTest is Test {
    TestUserProfileIntegration userProfile;
    address compoundingRole = address(1);
    address testUser = address(2);
    address testUser2 = address(20);
    // Dummy token addresses.
    address tokenA = address(3);
    address tokenB = address(4);
    // Sample update values.
    uint256 valA = 100;
    uint256 wdA = 50;
    uint256 debtA = 10;
    uint256 valB = 200;
    uint256 wdB = 70;
    uint256 debtB = 20;

    function setUp() public {
        // Deploy the integration test contract with dummy wormhole parameters.
        userProfile = new TestUserProfileIntegration(address(100), address(101), address(102));
        userProfile.grantRole(userProfile.COMPOUNDER_ROLE(), compoundingRole);

        // For integration, we assume the parent chain holds an active user profile.
        userProfile.setUserActive(testUser, true);
    }

    // --- INTEGRATION: Simulate side chain sending update to parent chain ---
    function testSideChainToParentChainSync() public {
        // On the side chain, a COMPOUNDER_ROLE caller updates the per-token profile.
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, tokenA, valA, wdA, debtA);

        // Simulate that the cross-chain message (payload) is created.
        bytes memory payloadA = abi.encode(testUser, tokenA, valA, wdA, debtA);

        // On the parent chain, the same payload is received.
        // For integration, we simulate this by calling testHandlePublic.
        vm.prank(compoundingRole);
        userProfile.testHandlePublic(testUser, payloadA);

        // Since the per-token update was executed on the side chain and then on the parent chain,
        // the totals should be accumulated.
        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            bool active,
            address tokenAddr
        ) = userProfile.userDataPerToken(testUser, tokenA);

        assertEq(totalInvested, valA * 2, "Invested should be doubled");
        assertEq(totalWithdrawn, wdA * 2, "Withdrawn should be doubled");
        assertEq(debt, debtA * 2, "Debt should be doubled");
        uint256 expectedCurrent = (valA - wdA - debtA) * 2;
        assertEq(currentValue, expectedCurrent, "Current value mismatch");
    }

    // --- INTEGRATION: Parent chain sends update to side chain for read-only data ---
    function testParentChainToSideChainSync() public {
        // On the parent chain, update a per-token profile for a different token.
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, tokenB, valB, wdB, debtB);

        // Simulate payload creation.
        bytes memory payloadB = abi.encode(testUser, tokenB, valB, wdB, debtB);

        // On the side chain, process the received payload.
        vm.prank(compoundingRole);
        userProfile.testHandlePublic(testUser, payloadB);

        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            bool active,
            address tokenAddr
        ) = userProfile.userDataPerToken(testUser, tokenB);

        assertEq(totalInvested, valB * 2, "Invested not aggregated correctly");
        assertEq(totalWithdrawn, wdB * 2, "Withdrawn not aggregated correctly");
        assertEq(debt, debtB * 2, "Debt not aggregated correctly");
        uint256 expectedCurrent = (valB - wdB - debtB) * 2;
        assertEq(currentValue, expectedCurrent, "Current value incorrect");
    }

    // --- INTEGRATION: Simulate duplicate payload processing ---
    function testDuplicatePayloadHandling() public {
        // Update profile on side chain.
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, tokenA, valA, wdA, debtA);

        // Create payload.
        bytes memory payload = abi.encode(testUser, tokenA, valA, wdA, debtA);

        // Simulate receiving the same payload twice (e.g., due to a network re-send).
        vm.prank(compoundingRole);
        userProfile.testHandlePublic(testUser, payload);
        vm.prank(compoundingRole);
        userProfile.testHandlePublic(testUser, payload);

        // Totals should have increased three times (1 from local update + 2 from duplicate payloads).
        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            bool active,
            address tokenAddr
        ) = userProfile.userDataPerToken(testUser, tokenA);

        uint256 multiplier = 1 + 2; // local update + 2 payloads
        assertEq(totalInvested, valA * multiplier, "Duplicate invested aggregation failed");
        assertEq(totalWithdrawn, wdA * multiplier, "Duplicate withdrawn aggregation failed");
        assertEq(debt, debtA * multiplier, "Duplicate debt aggregation failed");
        uint256 expectedCurrent = (valA - wdA - debtA) * multiplier;
        assertEq(currentValue, expectedCurrent, "Duplicate current value aggregation failed");
    }

    // --- INTEGRATION: Multi–chain aggregation for the same user ---
    function testMultiChainAggregation() public {
        // Simulate updates from two different side chains.
        // First update from chain 1:
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, tokenA, valA, wdA, debtA);
        bytes memory payload1 = abi.encode(testUser, tokenA, valA, wdA, debtA);
        vm.prank(compoundingRole);
        userProfile.testHandlePublic(testUser, payload1);

        // Second update from chain 2 with different values:
        uint256 extraVal = 150;
        uint256 extraWd = 60;
        uint256 extraDebt = 15;
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, tokenA, extraVal, extraWd, extraDebt);
        bytes memory payload2 = abi.encode(testUser, tokenA, extraVal, extraWd, extraDebt);
        vm.prank(compoundingRole);
        userProfile.testHandlePublic(testUser, payload2);

        // Aggregate expected values:
        uint256 totalInvestedExpected = (valA + extraVal) * 2; // each update applied locally and via payload
        uint256 totalWithdrawnExpected = (wdA + extraWd) * 2;
        uint256 totalDebtExpected = (debtA + extraDebt) * 2;
        uint256 expectedCurrent = totalInvestedExpected - totalWithdrawnExpected - totalDebtExpected;

        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            bool active,
            address tokenAddr
        ) = userProfile.userDataPerToken(testUser, tokenA);

        assertEq(totalInvested, totalInvestedExpected, "Multi-chain invested aggregation failed");
        assertEq(totalWithdrawn, totalWithdrawnExpected, "Multi-chain withdrawn aggregation failed");
        assertEq(debt, totalDebtExpected, "Multi-chain debt aggregation failed");
        assertEq(currentValue, expectedCurrent, "Multi-chain current value aggregation failed");
    }
}
