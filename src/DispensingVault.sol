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
import {TokenVault} from "./Vault.sol";

import "./utils/SafeMath.sol";

contract DispensingTokenVault is TokenVault{
    using SafeMath for uint256;
    uint maxPercentage = 100000;

    constructor(
        address _owner,
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) TokenVault(_owner, _wormholeRelayer, _tokenBridge, _wormhole){}

    function deposit(address _tokenAddress, uint256 _amount, uint256 _lockDuration, uint256 _amountToDispense, uint256 _dispensingPeriod) external onlyOwner whenNotPaused nonReentrant {
        deposit(_tokenAddress, _amount, _lockDuration);

        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        // depositInfo.lockDuration += _lockDuration;
        // depositInfo.amount = depositInfo.amount.add(_amount);
        depositInfo.amountDispenser = true;
        depositInfo.dispensingPeriod = _dispensingPeriod;
        depositInfo.percentageToDispense = 0;
        depositInfo.amountToDispense = _amountToDispense;
        depositInfo.lastDispensedTime = block.timestamp;
    }
    

    function changeDispensingSetting(address _tokenAddress, bool _amountDispenser, uint256 _dispensingPeriod, uint16 _percentageToDispense, uint256 _amountToDispense) onlyOwner external whenNotPaused {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens deposited");
        
        depositInfo.amountDispenser = _amountDispenser;
        depositInfo.dispensingPeriod = _dispensingPeriod;
        depositInfo.percentageToDispense = _percentageToDispense;
        depositInfo.amountToDispense = _amountToDispense;
        userDeposits[msg.sender][_tokenAddress] = depositInfo;
    }

    function dispenseFund(address _tokenAddress) external whenNotPaused onlyOwner nonReentrant {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.lastDispensedTime + depositInfo.dispensingPeriod <= block.timestamp, "Not yet time to dispense");

        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= depositInfo.amount, "Insufficient balance in the vault");

        uint amount = depositInfo.amountToDispense;
        if(!depositInfo.amountDispenser){
            //percentage
            amount = (depositInfo.amount * depositInfo.percentageToDispense) / maxPercentage;
        }

        withdraw(_tokenAddress, amount);

        depositInfo.amount = depositInfo.amount.sub(amount);
        _token.transfer(msg.sender, amount);
    }
}
