// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Messenger} from "./messenger/Messenger.sol";
import {IProvider} from "./provider/ProviderTemplate.sol";
import {DispensingTokenVault} from "./DispensingVault.sol";

contract DispensingCompoundingTokenVault is  DispensingTokenVault{
    constructor(
        address _owner,
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) DispensingTokenVault(_owner, _wormholeRelayer, _tokenBridge, _wormhole){}

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
}
