// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./hyperlanerouter.sol";

contract UserProfile is HyperLane{
    // User data mapping
    mapping(address => UserData) public userData;
    mapping(address => mapping(address => UserDataPerToken)) public userDataPerToken;
    bytes32 public constant COMPOUNDER_ROLE = keccak256("COMPOUNDER_ROLE");

    //total value of user
    struct UserData {
        uint256 currentValue;
        uint256 totalInvested;
        uint256 totalWithdrawn;
        uint256 debt;
        uint256 numberOfTokens;
        bool active;
    }

    // update on value of user per token
    struct UserDataPerToken {
        uint256 currentValue;
        uint256 totalInvested;
        uint256 totalWithdrawn;
        uint256 debt;
        bool active;
    }

    constructor(){
         _setupRole(COMPOUNDER_ROLE, msg.sender);
    }

    // Event to log profile updates
    event UserProfileUpdated(address user, address token, uint256 value, uint256 invested, uint256 debt);

    function updateUserProfile(address _user, address _token, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt) public {
        require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
        // TODO: need some USD conversion before using values (incorrect)
        UserData memory user = userData[_user];
        if (user.active ) {
            user.totalInvested += addedValue;
            user.totalWithdrawn += addedWithdrawn;
            user.debt += addedDebt;
            user.currentValue = user.totalInvested - user.totalWithdrawn - user.debt;

            if (!userDataPerToken[_user][_token].active) {
                user.numberOfTokens +=1;
            }
            userData[_user] = user;
        }

        updateUserProfilePerToken(_user, _token, addedValue, addedWithdrawn, addedDebt);
        emit UserProfileUpdated(_user, _token, addedValue, addedWithdrawn, addedDebt);
    }

    function updateUserProfilePerToken(address _user, address _token, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt) public {
        require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
        UserDataPerToken memory user = userDataPerToken[_user][_token];
        user.totalInvested += addedValue;
        user.totalWithdrawn += addedWithdrawn;
        user.debt += addedDebt;
        user.currentValue = user.totalInvested - user.totalWithdrawn - user.debt;
        userDataPerToken[_user][_token] = user;
    }

    function getUserProfile(address _user) external view returns(UserData memory user) {
        require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
        user = userData[_user];
    }

    function _handle(
        uint32 _origin,
        bytes32,
        bytes calldata _message
    ) internal override {
       (address _user, address _token, uint256 _addedValue, uint256 _addedWithdrawn, uint256 _addedDebt) = abi.decode(
            _message,
            (address, address, uint, uint, uint)
        );

        updateUserProfile(_user, _token, _addedValue, _addedWithdrawn, _addedDebt);
        emit ProfileUpdated(_origin, _user, _addedValue, _addedWithdrawn, _addedDebt);
    }
}
