// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/src/interfaces/IERC20.sol";

contract CrossChainSender is TokenSender {
    uint256 constant GAS_LIMIT = 250_000;

    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) TokenBase(_wormholeRelayer, _tokenBridge, _wormhole) {}

    // Function to get the estimated cost for cross-chain deposit
    function quoteCrossChainDeposit(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        uint256 deliveryCost;
        (deliveryCost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );

        cost = deliveryCost + wormhole.messageFee();
    }

    // Function to send tokens and payload across chains
    function sendCrossChainDeposit(
        uint16 targetChain,
        address targetReceiver,
        address recipient,
        uint256 amount,
        address token,
        bytes memory _extraData

    ) public payable virtual {
        uint256 cost = quoteCrossChainDeposit(targetChain);
        require(
            msg.value == cost,
            "msg.value must equal quoteCrossChainDeposit(targetChain)"
        );

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        bytes memory payload = abi.encode(recipient, _extraData);

        sendTokenWithPayloadToEvm(
            targetChain,
            targetReceiver,
            payload,
            cost,
            GAS_LIMIT,
            token,
            amount
        );
    }

    function sendMessage(
        uint16 targetChain,
        address targetAddress,
        bytes memory message
    ) public payable {
        uint256 cost = quoteCrossChainDeposit(targetChain);

        require(
            msg.value >= cost,
            "Insufficient funds for cross-chain delivery"
        );

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(msg.sender, message), // address, bytes
            0,
            GAS_LIMIT
        );
    }
}
