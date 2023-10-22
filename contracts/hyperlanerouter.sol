// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GasRouter} from "@hyperlane-xyz/core/contracts/GasRouter.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract HyperLane is GasRouter, AccessControlUpgradeable, Pausable{
    
    constructor(){}
    event ProfileUpdated(uint32 origin, address user, uint256 addedValue, uint256 addedWithdrawn, uint256 addedDebt);

    function _handle(
        uint32 _origin,
        bytes32,
        bytes calldata _message
    ) internal virtual override {
       (address _user, uint256 _addedValue, uint256 _addedWithdrawn, uint256 _addedDebt) = abi.decode(
            _message,
            (address, uint, uint, uint)
        );

        emit ProfileUpdated(_origin, _user, _addedValue, _addedWithdrawn, _addedDebt);
    }

    function _updateProfile(
        address _relayer,
        uint32 _destination,
        uint256 _gasPayment,
        address _user, 
        address _token,
        uint256 _addedValue, 
        uint256 _addedWithdrawn, 
        uint256 _addedDebt
    ) internal virtual returns (bytes32 messageId) {

         messageId = _dispatchWithGas(
            _destination,
            abi.encode(_user, _token, _addedValue, _addedWithdrawn, _addedDebt),
            _gasPayment,
            _relayer
        );
        
    }

     // Override the _msgData function
    function _msgData() internal pure override(Context, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }

    // Override the _msgSender function
    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

}
