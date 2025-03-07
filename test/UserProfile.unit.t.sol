// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/UserProfile.sol";

/// @dev A test version that exposes internal functions if needed.
contract TestUserProfileUnit is UserProfile {
    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) UserProfile(_wormholeRelayer, _tokenBridge, _wormhole) {}

    // Expose _handle if needed for unit testing (not integration)
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

contract UserProfile_UnitTest is Test {
    TestUserProfileUnit userProfile;
    address compoundingRole = address(1);
    address unauthorized = address(99);
    address testUser = address(2);
    // Dummy token address used for per-token updates.
    address testToken = address(3);
    // Sample update values.
    uint256 val1 = 100;
    uint256 wd1 = 50;
    uint256 debt1 = 10;
    uint256 val2 = 200;
    uint256 wd2 = 70;
    uint256 debt2 = 20;

    function setUp() public {
        // Deploy TestUserProfileUnit with dummy wormhole parameters.
        userProfile = new TestUserProfileUnit(address(100), address(101), address(102));
        // Grant the COMPOUNDER_ROLE to compoundingRole.
        userProfile.grantRole(userProfile.COMPOUNDER_ROLE(), compoundingRole);
    }

    // --- UNIT TESTS: Authorized updates ---

    function testUpdateUserProfilePerToken_Authorized() public {
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, testToken, val1, wd1, debt1);

        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            bool active,
            address tokenAddr
        ) = userProfile.userDataPerToken(testUser, testToken);

        uint256 expectedCurrent = val1 - wd1 - debt1;
        assertEq(totalInvested, val1, "Invested not set correctly");
        assertEq(totalWithdrawn, wd1, "Withdrawn not set correctly");
        assertEq(debt, debt1, "Debt not set correctly");
        assertEq(currentValue, expectedCurrent, "Current value mismatch");
        assertEq(tokenAddr, testToken, "Token address mismatch");
    }

    function testUpdateUserProfile_Authorized_WithActiveUser() public {
        // First, mark the user as active so that global profile is updated.
        userProfile.setUserActive(testUser, true);
        vm.prank(compoundingRole);
        // Call updateUserProfilePerToken to initialize per-token data.
        userProfile.updateUserProfilePerToken(testUser, testToken, 0, 0, 0);
        // Now update the global profile.
        vm.prank(compoundingRole);
        userProfile.updateUserProfile(testUser, testToken, val1, wd1, debt1);

        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            uint256 numberOfTokens,
            bool active
        ) = userProfile.userData(testUser);

        // Global profile is only updated if active is true.
        uint256 expectedCurrent = val1 - wd1 - debt1;
        assertEq(totalInvested, val1, "Global invested mismatch");
        assertEq(totalWithdrawn, wd1, "Global withdrawn mismatch");
        assertEq(debt, debt1, "Global debt mismatch");
        assertEq(currentValue, expectedCurrent, "Global current value mismatch");
    }

    function testMultipleUpdates_AccumulateCorrectly() public {
        // Activate the user.
        userProfile.setUserActive(testUser, true);
        vm.prank(compoundingRole);
        userProfile.updateUserProfilePerToken(testUser, testToken, val1, wd1, debt1);

        vm.prank(compoundingRole);
        userProfile.updateUserProfile(testUser, testToken, val2, wd2, debt2);

        // Get per-token data (note: both updateUserProfilePerToken and updateUserProfile
        // call the internal per-token update, so updates accumulate).
        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            bool active,
            address tokenAddr
        ) = userProfile.userDataPerToken(testUser, testToken);

        uint256 expectedInvested = val1 + val2;
        uint256 expectedWithdrawn = wd1 + wd2;
        uint256 expectedDebt = debt1 + debt2;
        uint256 expectedCurrent = expectedInvested - expectedWithdrawn - expectedDebt;

        assertEq(totalInvested, expectedInvested, "Accumulated invested incorrect");
        assertEq(totalWithdrawn, expectedWithdrawn, "Accumulated withdrawn incorrect");
        assertEq(debt, expectedDebt, "Accumulated debt incorrect");
        assertEq(currentValue, expectedCurrent, "Accumulated current value incorrect");
    }

    // --- UNIT TESTS: Unauthorized access ---

    function testUpdateUserProfilePerToken_Unauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert("Caller is not appoved for this call");
        userProfile.updateUserProfilePerToken(testUser, testToken, val1, wd1, debt1);
    }

    function testUpdateUserProfile_Unauthorized() public {
        // Even if user is active, unauthorized caller should revert.
        userProfile.setUserActive(testUser, true);
        vm.prank(unauthorized);
        vm.expectRevert("Caller is not appoved for this call");
        userProfile.updateUserProfile(testUser, testToken, val1, wd1, debt1);
    }

    // --- UNIT TESTS: Inactive user global profile remains unchanged ---
    function testUpdateUserProfile_InactiveUser() public {
        // By default, userData[testUser].active is false.
        vm.prank(compoundingRole);
        userProfile.updateUserProfile(testUser, testToken, val1, wd1, debt1);

        // Global user data should not update because active flag is false.
        (
            uint256 currentValue,
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 debt,
            uint256 numberOfTokens,
            bool active
        ) = userProfile.userData(testUser);

        // All values remain zero since active check prevents update.
        assertEq(totalInvested, 0, "Global invested should remain zero");
        assertEq(totalWithdrawn, 0, "Global withdrawn should remain zero");
        assertEq(debt, 0, "Global debt should remain zero");
        assertEq(currentValue, 0, "Global current value should remain zero");
    }
}
