// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Messenger} from "./Messenger.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract UserProfile is Messenger, AccessControl{
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
        address token;
    }

    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) Messenger(_wormholeRelayer, _tokenBridge, _wormhole){
         _grantRole(COMPOUNDER_ROLE, msg.sender);
    }

    // Event to log profile updates
    event UserProfileUpdated(address user, address token, uint256 value, uint256 invested, uint256 debt);
    event ProfileUpdated(address user, uint256 value, uint256 invested, uint256 debt);

    function updateUserProfile(address _user, address _token, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt) external {
      require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
      _updateUserProfile(_user, _token, addedValue, addedWithdrawn, addedDebt);
    }

    function updateUserProfilePerToken(address _user, address _token, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt) external {
      require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
      _updateUserProfilePerToken(_user, _token, addedValue, addedWithdrawn, addedDebt);
    }

    function _updateUserProfile(address _user, address _token, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt) internal {
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
        _updateUserProfilePerToken(_user, _token, addedValue, addedWithdrawn, addedDebt);
        emit UserProfileUpdated(_user, _token, addedValue, addedWithdrawn, addedDebt);
    }

    function _updateUserProfilePerToken(address _user, address _token, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt) internal {
        UserDataPerToken memory user = userDataPerToken[_user][_token];
        user.totalInvested += addedValue;
        user.totalWithdrawn += addedWithdrawn;
        user.debt += addedDebt;
        user.currentValue = user.totalInvested - user.totalWithdrawn - user.debt;
        user.token = _token;
        userDataPerToken[_user][_token] = user;

        bytes memory payload = abi.encode(_user, _token, addedValue,addedWithdrawn,  addedDebt);

        sendMessageToAllChains(payload);
    }

    function getUserProfile(address _user) external view returns(UserData memory user) {
        require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
        user = userData[_user];
    }

    function getUserProfilePerToken(address _user,  address _token) external view returns(UserDataPerToken memory user) {
        require(hasRole(COMPOUNDER_ROLE, msg.sender), "Caller is not appoved for this call");
        user = userDataPerToken[_user][_token];
    }

    function _handle(
        address recipient,
        bytes memory _message
    ) internal virtual override {
        (address _user, address _token, uint256 _addedValue, uint256 _addedWithdrawn,  uint256 _addedDebt) = abi.decode(
            _message,
            (address, address, uint256, uint256, uint256)
        );

        _updateUserProfile(_user, _token, _addedValue, _addedWithdrawn, _addedDebt);
        emit ProfileUpdated(_user, _addedValue, _addedWithdrawn, _addedDebt);
    }

    // deactivate token transfer on user profile
    function sendCrossChainDeposit(
        uint16 targetChain,
        address targetReceiver,
        address recipient,
        uint256 amount,
        address token,
        bytes memory _extraData
    ) public payable override {
      revert("Not supported");
    }

    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    )
        internal
        virtual
        override
        onlyWormholeRelayer
        isRegisteredSender(sourceChain, sourceAddress)
    {
      revert("Not supported");
    }
}
