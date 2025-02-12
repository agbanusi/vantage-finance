// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Messenger} from "./messenger/Messenger.sol";
import {IProvider} from "./provider/ProviderTemplate.sol";
import {TokenVault} from "./Vault.sol";

//vault with principal compounding

contract CompoundingTokenVault is TokenVault {
    
    constructor(address _owner) Ownable(_owner) {}

    function compoundInvestment(address _token) external nonReentrant {      
        uint256 initialBalance = IERC20(_token).balanceOf(address(this));
        for (uint i = 0; i < activeProviders.length; i++) {
            IProvider(activeProviders[i]).skim(_token);
        }
        uint256 rewards = IERC20(_token).balanceOf(address(this)) - initialBalance;

        if (rewards > 0 && activeProviders.length > 0) {
            uint256 share = rewards / activeProviders.length;
            uint256 remainder = rewards % activeProviders.length;
            
            for (uint i = 0; i < activeProviders.length; i++) {
                uint256 amount = share + (i < remainder ? 1 : 0);
                IERC20(_token).approve(activeProviders[i], amount);
                IProvider(activeProviders[i]).deposit(_token, amount);
            }
        }

        _updateProfile(owner(), _token, rewards, 0, 0);
    }

    function _handle(
        address _user,
        bytes calldata _message
    ) internal override {
        // (address _user, address _token, uint256 _addedValue, uint256 _addedWithdrawn,  uint256 _addedDebt) = abi.decode(
        //     _message,
        //     (address, address, uint256, uint256, uint256)
        // );

        // _updateUserProfile(_user, _token, _addedValue, _addedWithdrawn, _addedDebt);
        emit ProfileUpdated(_user, _addedValue, _addedWithdrawn, _addedDebt);
    }
}
