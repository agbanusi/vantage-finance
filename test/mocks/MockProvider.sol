pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Minimal IProvider interface including skim().
interface IProvider {
    function deposit(address _token, uint256 _amount) external;
    function withdraw(address _token, uint256 _amount)
        external
        returns (uint256);
    function getTVL(address _token) external view returns (uint256);
    function skim(address _token) external;
}

// A mock provider that supports deposit, withdraw, and skim.
contract MockProvider is IProvider {
    mapping(address => uint256) public balances;
    uint256 public extraReward;

    function deposit(address _token, uint256 _amount) external override {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        balances[_token] += _amount;
    }

    function withdraw(address _token, uint256 _amount)
        external
        override
        returns (uint256)
    {
        uint256 currentBalance = balances[_token];
        uint256 toWithdraw = _amount > currentBalance ? currentBalance : _amount;
        if (toWithdraw > 0) {
            balances[_token] -= toWithdraw;
            IERC20(_token).transfer(msg.sender, toWithdraw);
        }
        return toWithdraw;
    }

    function getTVL(address _token) external view override returns (uint256) {
        return balances[_token];
    }

    function setExtraReward(uint256 _reward) external {
        extraReward = _reward;
    }

    function skim(address _token) external override {
        if (extraReward > 0) {
            IERC20(_token).transfer(msg.sender, extraReward);
        }
    }
}