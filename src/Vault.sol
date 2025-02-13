// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./utils/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Messenger} from "./messenger/Messenger.sol";
import {IProvider} from "./provider/ProviderTemplate.sol";


//basic vault for erc20 with principal compounding

contract TokenVault is ReentrancyGuard, Messenger, Ownable, Pausable {
    using SafeMath for uint256;
    struct TokenDeposit {
        uint256 amount;
        uint256 lockDuration;
        uint256 dispensingPeriod;
        bool amountDispenser;
        uint16 percentageToDispense; //3dp
        uint256 amountToDispense;
        uint256 lastDispensedTime;
    }

    IERC20 public weth;
    uint256 public defaultUnlock = 128 days;
    uint32 profileDestination;
    address[] public allProviders;
    address[] public activeProviders;
    
    mapping(address => bool) public isActiveProvider;
    mapping(address => mapping(address => TokenDeposit)) public userDeposits;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant COMPOUNDER_ROLE = keccak256("COMPOUNDER_ROLE");

    constructor(
        address _owner,
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) Messenger(_wormholeRelayer, _tokenBridge, _wormhole) Ownable(_owner) {}

    receive() external payable{
        address tempAddress = address(weth);
        uint _amount = msg.value;
        require(msg.value > 0, "Amount must be greater than 0");
        
        uint balanceBefore = weth.balanceOf(address(this));
        (bool success,) = address(weth).call{value: msg.value}("");
        require(success, "eth depsoit failed");
        uint balanceAfter = weth.balanceOf(address(this));
        require(balanceAfter >= balanceBefore+_amount, "invalid weth conversion");

        TokenDeposit storage depositInfo = userDeposits[msg.sender][tempAddress];
        depositInfo.lockDuration += defaultUnlock;
        depositInfo.amount = depositInfo.amount.add(msg.value);

        uint256 providerCount = activeProviders.length;
        require(providerCount > 0, "No providers available");
        uint256 share = _amount / providerCount;
        uint256 remainder = _amount % providerCount;

        for (uint i = 0; i < activeProviders.length; i++) {
            uint256 amountToSend = share + (i < remainder ? 1 : 0);
            IERC20(tempAddress).approve(activeProviders[i], amountToSend);
            IProvider(activeProviders[i]).deposit(tempAddress, amountToSend);
        }
        
        _updateProfile(owner(), tempAddress, msg.value, 0,0);
    }

    // Provider Management Functions
    function addProvider(address provider) external onlyOwner {
        require(!isActiveProvider[provider], "Provider already active");
        if (!_isProvider(provider)) {
            allProviders.push(provider);
        }
        activeProviders.push(provider);
        isActiveProvider[provider] = true;
    }

    function removeProvider(address provider) external onlyOwner {
        require(isActiveProvider[provider], "Provider not active");
        for (uint i = 0; i < activeProviders.length; i++) {
            if (activeProviders[i] == provider) {
                activeProviders[i] = activeProviders[activeProviders.length - 1];
                activeProviders.pop();
                break;
            }
        }
        isActiveProvider[provider] = false;
    }

    function _isProvider(address provider) private view returns (bool) {
        if (isActiveProvider[provider]) return true;
        return false;
    }

    function deposit(address _tokenAddress, uint256 _amount, uint256 _lockDuration) public virtual whenNotPaused onlyOwner nonReentrant {
        require(block.timestamp < _lockDuration, "Tokens can't be deposited after the unlock time");
        require(_amount > 0, "Amount must be greater than 0");

        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        depositInfo.lockDuration += _lockDuration;
        depositInfo.amount = depositInfo.amount.add(_amount);

        uint256 providerCount = activeProviders.length;
        require(providerCount > 0, "No providers available");
        uint256 share = _amount / providerCount;
        uint256 remainder = _amount % providerCount;

        for (uint i = 0; i < activeProviders.length; i++) {
            uint256 amountToSend = share + (i < remainder ? 1 : 0);
            IERC20(_tokenAddress).approve(activeProviders[i], amountToSend);
            IProvider(activeProviders[i]).deposit(_tokenAddress, amountToSend);
        }
        _updateProfile(owner(), _tokenAddress, _amount, 0,0);
    }

    function changeLockDuration(address _tokenAddress, uint256 _newLockDuration) external onlyOwner whenNotPaused {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens deposited");
        require(_newLockDuration > block.timestamp, "Duration cannot be in the past");

        depositInfo.lockDuration = _newLockDuration;
        userDeposits[msg.sender][_tokenAddress] = depositInfo;
    }

    function withdraw(address _tokenAddress, uint256 _amount) public whenNotPaused onlyOwner nonReentrant {
        TokenDeposit storage depositInfo = userDeposits[msg.sender][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens to withdraw");
        require(block.timestamp >= depositInfo.lockDuration, "Tokens can't be withdrawn before the unlock time");

        (address[] memory providers, uint256[] memory tvls) = _getSortedProviders(_tokenAddress);
        uint256 remaining = _amount;
        for (uint i = 0; i < providers.length; i++) {
            if (remaining == 0) break;
            uint256 tvl = tvls[i];
            uint256 toWithdraw = remaining > tvl ? tvl : remaining;
            uint256 withdrawn = IProvider(providers[i]).withdraw(_tokenAddress, toWithdraw);
            remaining -= withdrawn;
        }
        require(remaining == 0, "Insufficient liquidity");

        depositInfo.amount = depositInfo.amount.sub(_amount);
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
        _updateProfile(owner(), _tokenAddress, 0, _amount, 0);
    }

    function withdrawWithSignature(address _user, address _tokenAddress, uint256 _amount, bytes memory signature) external whenNotPaused onlyOwner nonReentrant {
        TokenDeposit storage depositInfo = userDeposits[_user][_tokenAddress];
        require(depositInfo.amount > 0, "No tokens to withdraw");
        require(block.timestamp >= depositInfo.lockDuration, "Tokens can't be withdrawn before the unlock time");

        bytes32 message = keccak256(abi.encodePacked(_user, _tokenAddress, _amount));
        require(_verifySignature(message, signature, _user), "Invalid signature");
        require(depositInfo.amount > 0, "No tokens to withdraw");

        (address[] memory providers, uint256[] memory tvls) = _getSortedProviders(_tokenAddress);
        uint256 remaining = _amount;
        for (uint i = 0; i < providers.length; i++) {
            if (remaining == 0) break;
            uint256 tvl = tvls[i];
            uint256 toWithdraw = remaining > tvl ? tvl : remaining;
            uint256 withdrawn = IProvider(providers[i]).withdraw(_tokenAddress, toWithdraw);
            remaining -= withdrawn;
        }
        require(remaining == 0, "Insufficient liquidity");

        depositInfo.amount = depositInfo.amount.sub(_amount);
        IERC20(_tokenAddress).transfer(_user, _amount);
        _updateProfile(owner(), _tokenAddress, 0, _amount, 0);
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

    function _handle(
        address _user,
        bytes memory _message
    ) internal virtual override {
        // (address _user, address _token, uint256 _addedValue, uint256 _addedWithdrawn,  uint256 _addedDebt) = abi.decode(
        //     _message,
        //     (address, address, uint256, uint256, uint256)
        // );

        // _updateUserProfile(_user, _token, _addedValue, _addedWithdrawn, _addedDebt);
        // emit ProfileUpdated(_user, _addedValue, _addedWithdrawn, _addedDebt);
    }

    // Rebalance Function
    function rebalance(address _tokenAddress) external {
        uint256 total;
        IERC20 token = IERC20(_tokenAddress);

        // Withdraw from all providers
        for (uint i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            uint256 tvl = IProvider(provider).getTVL(_tokenAddress);
            if (tvl > 0) {
                total += IProvider(provider).withdraw(_tokenAddress, tvl);
            }
        }

        // Include vault balance
        total += token.balanceOf(address(this));
        uint256 providerCount = activeProviders.length;
        require(providerCount > 0, "No active providers");

        // Distribute to active providers
        uint256 share = total / providerCount;
        uint256 remainder = total % providerCount;

        for (uint i = 0; i < activeProviders.length; i++) {
            uint256 amount = share + (i < remainder ? 1 : 0);
            token.approve(activeProviders[i], amount);
            IProvider(activeProviders[i]).deposit(_tokenAddress, amount);
        }
    }

    // Helper to sort providers by TVL
    function _getSortedProviders(address _tokenAddress) private view returns (address[] memory, uint256[] memory) {
        address[] memory providers = activeProviders;
        uint256[] memory tvls = new uint256[](providers.length);

        for (uint i = 0; i < providers.length; i++) {
            tvls[i] = IProvider(providers[i]).getTVL(_tokenAddress);
        }

        // Insertion sort
        for (uint i = 1; i < providers.length; i++) {
            uint j = i;
            while (j > 0 && tvls[j-1] > tvls[j]) {
                (tvls[j-1], tvls[j]) = (tvls[j], tvls[j-1]);
                (providers[j-1], providers[j]) = (providers[j], providers[j-1]);
                j--;
            }
        }

        return (providers, tvls);
    }
}