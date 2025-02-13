// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CrossChainReceiver} from "./MessageReceiver.sol";

contract Messenger is CrossChainReceiver {
    // Role-based access control
    mapping(address => bool) public isApprovedRelayer; // Mapping of approved relayers

    // Chain management
    uint16[] public whitelistedChains; // List of whitelisted chain IDs
    mapping(uint16 => bool) public isWhitelisted; // Mapping to check if a chain is whitelisted
    mapping(uint16 => address) public targetMessengerAddresses; // Mapping of chain ID to target address

    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        CrossChainReceiver(_wormholeRelayer, _tokenBridge, _wormhole)
    {
        // The deployer is the first approved relayer
        isApprovedRelayer[msg.sender] = true;
    }

    modifier onlyApprovedRelayer() {
        require(isApprovedRelayer[msg.sender], "Only approved relayers can call this function");
        _;
    }

    // Function to add a new approved relayer
    function addApprovedRelayer(address relayer) external onlyApprovedRelayer {
        require(!isApprovedRelayer[relayer], "Relayer already approved");
        isApprovedRelayer[relayer] = true;
    }

    // Function to remove an approved relayer
    function removeApprovedRelayer(address relayer) external onlyApprovedRelayer {
        require(isApprovedRelayer[relayer], "Relayer not approved");
        isApprovedRelayer[relayer] = false;
    }

    // Function to add a new chain to the whitelist
    function addWhitelistedChain(uint16 chainId) external onlyApprovedRelayer {
        require(!isWhitelisted[chainId], "Chain already whitelisted");
        isWhitelisted[chainId] = true;
        whitelistedChains.push(chainId);
    }

    // Function to remove a chain from the whitelist
    function removeWhitelistedChain(uint16 chainId) external onlyApprovedRelayer {
        require(isWhitelisted[chainId], "Chain not whitelisted");
        isWhitelisted[chainId] = false;

        // Remove the chain from the whitelistedChains list
        for (uint256 i = 0; i < whitelistedChains.length; i++) {
            if (whitelistedChains[i] == chainId) {
                // Swap with the last element and pop
                whitelistedChains[i] = whitelistedChains[whitelistedChains.length - 1];
                whitelistedChains.pop();
                break;
            }
        }
    }

    // Function to set the target messenger address for a specific chain
    function setTargetMessengerAddress(uint16 chainId, address targetAddress) external onlyApprovedRelayer {
        require(isWhitelisted[chainId], "Chain is not whitelisted");
        targetMessengerAddresses[chainId] = targetAddress;
    }

    // Function to send a message to all whitelisted chains except the sender chain
    function sendMessageToAllChains(bytes memory message) public payable {
        uint16 senderChain = wormhole.chainId();
        uint value = msg.value;

        // Iterate through the list of whitelisted chains
        for (uint256 i = 0; i < whitelistedChains.length; i++) {
            uint16 chainId = whitelistedChains[i];

            // Skip the sender chain
            if (chainId == senderChain) {
                continue;
            }

            address targetAddress = targetMessengerAddresses[chainId];
            require(targetAddress != address(0), "Target address not set for chain");

            // Estimate the cost for sending the message
            uint256 cost = quoteCrossChainDeposit(chainId);
            require(value >= cost, "Insufficient funds for cross-chain delivery");
            value -= cost;

            // Send the message to the target chain
            sendMessage(chainId, targetAddress, message);
        }
    }

    function _updateProfile(
        address _user, 
        address _token,
        uint256 _addedValue, 
        uint256 _addedWithdrawn, 
        uint256 _addedDebt
    ) internal virtual returns (bytes32 messageId) {
        bytes memory message = abi.encode(_user, _token, _addedValue, _addedWithdrawn, _addedDebt);
        sendMessageToAllChains(message);
    }
}