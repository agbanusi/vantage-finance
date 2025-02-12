// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IProvider {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external returns (uint256);
    function skim(address token) external;
    function getUserBalance(address user, address token) external view returns (uint256);
    function getTVL(address token) external view returns (uint256);
}

abstract contract ProviderTemplate is IProvider, Ownable {
    mapping(address => uint256) public totalDeposits;
    mapping(address => mapping(address => uint256)) public userBalances;

    function deposit(address token, uint256 amount) external virtual override {
        require(amount > 0, "Amount must be > 0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        totalDeposits[token] += amount;
        userBalances[msg.sender][token] += amount;
    }

    function withdraw(address token, uint256 amount) external virtual override returns (uint256) {
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");
        userBalances[msg.sender][token] -= amount;
        totalDeposits[token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        return amount;
    }

    function skim(address token) external virtual override {
        // Implement reward collection logic
    }

    function getUserBalance(address user, address token) external view virtual override returns (uint256) {
        return userBalances[user][token];
    }

    function getTVL(address token) external view virtual override returns (uint256) {
        return totalDeposits[token];
    }
}