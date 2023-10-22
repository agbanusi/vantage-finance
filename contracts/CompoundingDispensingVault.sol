// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./hyperlanerouter.sol";

//dispensing vault for erc20 and disp

contract TokenVault is  ReentrancyGuard, HyperLane {
    using SafeMath for uint256;
    uint maxPercentage = 100000;

    struct TokenDeposit {
        uint256 amount;
        uint256 lockDuration;
        uint256 dispensingPeriod;
        bool amountDispenser;
        uint16 percentageToDispense; //3dp
        uint256 amountToDispense;
        uint256 lastDispensedTime;
    }

    IERC20 public token;
    uint256 public defaultUnlock = 128 days;
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    address relayer;
    uint32 profileDestination;

    mapping(address => mapping(address => TokenDeposit)) public userDeposits;

    constructor(uint32 _destination) {
        _setupRole(RELAYER_ROLE, msg.sender);
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
                lockDuration: defaultUnlock,
                amountDispenser: false,
                dispensingPeriod: 30 days,
                percentageToDispense: 8333,
                amountToDispense:0,
                lastDispensedTime: block.timestamp
            });
        }else{
            depositInfo.lockDuration += defaultUnlock;
            depositInfo.amount = depositInfo.amount.add(msg.value);
            userDeposits[msg.sender][tempAddress] = depositInfo;
        }
        _updateProfile(relayer, profileDestination, 100000, msg.sender, tempAddress, msg.value, 0,0);
    }

    function deposit(address _tokenAddress, uint256 _amount, uint256 _lockDuration, uint16 _percentageToDispense, uint256 _dispensingPeriod) external whenNotPaused nonReentrant {
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
                lockDuration: _lockDuration,
                amountDispenser: false,
                dispensingPeriod: _dispensingPeriod,
                percentageToDispense: _percentageToDispense,
                amountToDispense:0,
                lastDispensedTime: block.timestamp
            });
        }else{
            depositInfo.lockDuration += _lockDuration;
            depositInfo.amount = depositInfo.amount.add(_amount);
            userDeposits[msg.sender][_tokenAddress] = depositInfo;
        }
        _updateProfile(relayer, profileDestination, 100000, msg.sender,_tokenAddress,  _amount, 0,0);
    }

    function deposit(address _tokenAddress, uint256 _amount, uint256 _lockDuration, uint256 _amountToDispense, uint256 _dispensingPeriod) external whenNotPaused nonReentrant {
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
                lockDuration: _lockDuration,
                amountDispenser: true,
                dispensingPeriod: _dispensingPeriod,
                percentageToDispense: 0,
                amountToDispense:_amountToDispense,
                lastDispensedTime: block.timestamp
            });
        }else{
            depositInfo.lockDuration += _lockDuration;
            depositInfo.amount = depositInfo.amount.add(_amount);
            userDeposits[msg.sender][_tokenAddress] = depositInfo;
        }
        _updateProfile(relayer, profileDestination, 100000, msg.sender, _tokenAddress, _amount, 0, 0);
    }

    function changeLockDuration(address _tokenAddress, uint256 _newLockDuration) external whenNotPaused {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens deposited");
        require(_newLockDuration > block.timestamp, "Duration cannot be in the past");

        depositInfo.lockDuration = _newLockDuration;
        userDeposits[msg.sender][_tokenAddress] = depositInfo;
    }

    function changeDispensingSetting(address _tokenAddress, bool _amountDispenser, uint256 _dispensingPeriod, uint16 _percentageToDispense, uint256 _amountToDispense) external whenNotPaused {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens deposited");
        
        depositInfo.amountDispenser = _amountDispenser;
        depositInfo.dispensingPeriod = _dispensingPeriod;
        depositInfo.percentageToDispense = _percentageToDispense;
        depositInfo.amountToDispense = _amountToDispense;
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

    function dispenseFund(address _tokenAddress) external whenNotPaused nonReentrant {
        require(hasRole(RELAYER_ROLE, msg.sender), "Caller is not appoved for this call");
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

        depositInfo.amount = depositInfo.amount.sub(amount);
        _token.transfer(msg.sender, amount);
        _updateProfile(relayer, profileDestination, 100000, msg.sender, _tokenAddress, 0, amount, 0);
    }

    function clearStuckFunds(address _tokenAddress, address _recipient) external onlyOwner {
        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No funds to clear");
        _token.transfer(_recipient, balance);
    }

    function _verifySignature(bytes32 message, bytes memory signature, address signer) internal pure returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address recoveredSigner = ECDSA.recover(hash, signature);
        return recoveredSigner == signer;
    }

    function compoundInvestment(address _token, address user, bytes[] memory data, bytes32[] memory sampleResults, uint _extraAmount) external nonReentrant{
        require(hasRole(RELAYER_ROLE, msg.sender), "Caller is not appoved for this call");
        TokenDeposit storage depositInfo = userDeposits[user][_token];
        bytes[] memory results = externalCall(_token, data, sampleResults); //TODO: use result to determine amount to compound
        // call external call,
        //withdraw
        //withdraw amount
        //deposit
        //update amount gotten from result
        depositInfo.amount = depositInfo.amount.add(_extraAmount);
        userDeposits[msg.sender][_token] = depositInfo;
        _updateProfile(relayer, profileDestination, 100000, msg.sender, _token, _extraAmount, 0,0);
    }

    function externalCall(address target, bytes[] memory data, bytes32[] memory sampleResults) public returns (bytes[] memory) {
        require(
            data.length <= 3,
            "Array length be at most 3"
        );
        bytes[] memory results = new bytes[](data.length);

        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = target.call(data[i]);

            if (success && keccak256(result) == sampleResults[i]) {
                results[i] = result;
            }else{
                revert();
            }
        }

        return results;
    }

    
}
