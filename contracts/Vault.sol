// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./hyperlanerouter.sol";


//basic vault for erc20 with principal compounding

contract TokenVault is ReentrancyGuard, HyperLane {
    using SafeMath for uint256;

    struct TokenDeposit {
        uint256 amount;
        uint256 lockDuration;
    }

    IERC20 public token;
    uint256 public defaultUnlock = 128 days;
    address relayer;
    uint32 profileDestination;

    mapping(address => mapping(address => TokenDeposit)) public userDeposits;

    constructor(uint32 _destination) {
        relayer = msg.sender;
        profileDestination = _destination;
    }

    receive() external payable{
        address tempAddress = address(1001);
        require(msg.value > 0, "Amount must be greater than 0");

        TokenDeposit storage depositInfo = userDeposits[msg.sender][tempAddress];

        if(depositInfo.amount ==0){
            userDeposits[msg.sender][tempAddress] = TokenDeposit({
                amount: msg.value,
                lockDuration: defaultUnlock
            });
        }else{
            depositInfo.lockDuration += defaultUnlock;
            depositInfo.amount = depositInfo.amount.add(msg.value);
            userDeposits[msg.sender][tempAddress] = depositInfo;
        }
        _updateProfile(relayer, profileDestination, 100000, msg.sender, tempAddress, msg.value, 0,0);
    }

    function deposit(address _tokenAddress, uint256 _amount, uint256 _lockDuration) external whenNotPaused nonReentrant {
        require(block.timestamp < _lockDuration, "Tokens can't be deposited after the unlock time");
        require(_amount > 0, "Amount must be greater than 0");

        IERC20 _token = IERC20(_tokenAddress);
        uint256 allowance = _token.allowance(msg.sender, address(this));

        require(allowance >= _amount, "Allowance not sufficient");

        _token.transferFrom(msg.sender, address(this), _amount);
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];

        if(depositInfo.amount ==0){
            userDeposits[msg.sender][_tokenAddress] = TokenDeposit({
                amount: _amount,
                lockDuration: _lockDuration
            });
        }else{
            depositInfo.lockDuration += _lockDuration;
            depositInfo.amount = depositInfo.amount.add(_amount);
            userDeposits[msg.sender][_tokenAddress] = depositInfo;
        }
        
        _updateProfile(relayer, profileDestination, 100000, msg.sender, _tokenAddress, _amount, 0,0);
    }

    function changeLockDuration(address _tokenAddress, uint256 _newLockDuration) external whenNotPaused {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens deposited");
        require(_newLockDuration > block.timestamp, "Duration cannot be in the past");

        depositInfo.lockDuration = _newLockDuration;
        userDeposits[msg.sender][_tokenAddress] = depositInfo;
    }

    function withdraw(address _tokenAddress, uint256 _amount) external whenNotPaused nonReentrant {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens to withdraw");
        require(block.timestamp >= depositInfo.lockDuration, "Tokens can't be withdrawn before the unlock time");

        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= depositInfo.amount, "Insufficient balance in the vault");
        require(_amount <= depositInfo.amount, "Insufficient balance for user");

        depositInfo.amount = depositInfo.amount.sub(_amount);
        _token.transfer(msg.sender, _amount);
        _updateProfile(relayer, profileDestination, 100000, msg.sender, _tokenAddress, 0, _amount, 0);
    }

    function withdrawWithSignature(address _user, address _tokenAddress, uint256 _amount, bytes memory signature) external whenNotPaused nonReentrant {
        TokenDeposit storage depositInfo = userDeposits[_user][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens to withdraw");
        require(block.timestamp >= depositInfo.lockDuration, "Tokens can't be withdrawn before the unlock time");

        bytes32 message = keccak256(abi.encodePacked(_user, _tokenAddress, _amount));
        require(_verifySignature(message, signature, _user), "Invalid signature");
        require(depositInfo.amount > 0, "No tokens to withdraw");

        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= depositInfo.amount, "Insufficient balance in the vault");
        require(_amount <= depositInfo.amount, "Insufficient balance for user");

        depositInfo.amount = depositInfo.amount.sub(_amount);
        _token.transfer(_user, _amount);
        _updateProfile(relayer, profileDestination, 100000, _user, _tokenAddress, 0, _amount, 0);
    }

    function _verifySignature(bytes32 message, bytes memory signature, address signer) internal pure returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address recoveredSigner = ECDSA.recover(hash, signature);
        return recoveredSigner == signer;
    }

    function clearStuckFunds(address _tokenAddress, address _recipient) external onlyOwner {
        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No funds to clear");
        _token.transfer(_recipient, balance);
    }
}
