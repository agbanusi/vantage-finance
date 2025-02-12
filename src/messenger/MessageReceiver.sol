// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "lib/wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IERC20.sol";

contract CrossChainReceiver is TokenReceiver {
    // The Wormhole relayer and registeredSenders are inherited from the Base.sol contract

    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) TokenBase(_wormholeRelayer, _tokenBridge, _wormhole) {
      registrationOwner = msg.sender;
    }

    modifier isRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) {
        require(
            registeredSenders[sourceChain] == sourceAddress,
            "Not registered sender"
        );
        _;
    }

    function setRegisteredSender(
        uint16 sourceChain,
        bytes32 sourceAddress
    ) public {
        require(
            msg.sender == registrationOwner,
            "Not allowed to set registered sender"
        );
        registeredSenders[sourceChain] = sourceAddress;
    }

    // Function to receive the cross-chain payload and tokens with emitter validation
    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    )
        internal
        virtual
        override
        onlyWormholeRelayer
        isRegisteredSender(sourceChain, sourceAddress)
    {
        require(receivedTokens.length == 1, "Expected 1 token transfer");

        // Decode the recipient address from the payload
        (address recipient, bytes memory extraData) = abi.decode(payload, (address, bytes32));

        // Transfer the received tokens to the intended recipient
        if(extraData != bytes(0)){
          _handle(user, extraData);
        }else{
          IERC20(receivedTokens[0].tokenAddress).transfer(
              recipient,
              receivedTokens[0].amount
          );
        }

    }

    function _handle(
        // uint32 _origin,
        address _user,
        bytes calldata _message
    ) internal virtual {}

    // Update receiveWormholeMessages to include the source address check
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32
    ) public payable override isRegisteredSender(sourceChain, sourceAddress) {
        require(
            msg.sender == address(wormholeRelayer),
            "Only the Wormhole relayer can call this function"
        );

        if (sourceChain == 0) {
            revert("Invalid Source Chain");
        }

        // Decode the payload to extract the message
        (address user,bytes memory message) = abi.decode(payload, (address, bytes));

        _handle(user, message);
    }
}