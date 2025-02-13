// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/src/interfaces/IERC20.sol";
import {CrossChainSender} from "./MessageSender.sol";

contract CrossChainReceiver is TokenReceiver, CrossChainSender {
    // The Wormhole relayer and registeredSenders are inherited from the Base.sol contract

    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) CrossChainSender(_wormholeRelayer, _tokenBridge, _wormhole) {
      registrationOwner = msg.sender;
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
        (address recipient, bytes memory extraData) = abi.decode(payload, (address, bytes));

        // Transfer the received tokens to the intended recipient
        if(extraData.length != 0){
          _handle(recipient, extraData);
        }else{
          IERC20(receivedTokens[0].tokenAddress).transfer(
              recipient,
              receivedTokens[0].amount
          );
        }

    }

    function _handle(
        address _user,
        bytes memory _message
    ) internal virtual {}
}