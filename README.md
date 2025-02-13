# Vantage Finance Protocol
Welcome to the Vantage Finance Protocol! This protocol is designed to help users lock their investments, compound them, or gradually dispense part of them to improve on-chain financial responsibility while earning yields on their locked value. The vault can also be used to transfer to owned vaults off-chain to improve earnings and capture yields across chains.

## Contracts Overview
- Messenger.sol
- CentralUserProfile.sol
- Vault.sol
- DispensingVault.sol
- CompoundingVault.sol
- DispensingCompoundingVault.sol

## Usage
- Saving in a Vault
- Compounding Investments
- Dispensing Investments
- Transferring to Off-Chain Vaults


Introduction
The Vantage Finance Protocol aims to provide a robust and flexible system for managing on-chain investments. Users can lock their investments in various types of vaults, each offering different functionalities such as compounding yields or dispensing funds gradually. Additionally, the protocol supports transferring assets to off-chain vaults to capture yields across different chains.

Contracts Overview
`Messenger.sol`
The Messenger.sol contract is responsible for handling communication between different parts of the protocol. It ensures that messages and data are correctly transmitted and received, facilitating smooth interactions within the protocol.

`CentralUserProfile.sol`
The CentralUserProfile.sol contract manages user profiles within the Vantage Finance Protocol. It stores user information and preferences, allowing for personalized interactions and streamlined management of user assets.

`Vault.sol`
The Vault.sol contract is the base contract for all vault types in the protocol. It provides the core functionality for locking and managing investments. Users can create vaults, deposit funds, and manage their investments through this contract.

`DispensingVault.sol`
The DispensingVault.sol contract extends the base Vault.sol contract to add functionality for gradually dispensing funds. Users can set up a schedule for dispensing their investments over time, promoting financial responsibility and controlled spending.

`CompoundingVault.sol`
The CompoundingVault.sol contract extends the base Vault.sol contract to add functionality for compounding yields. Investments in this vault type automatically earn and reinvest yields, maximizing returns over time.

`DispensingCompoundingVault.sol`
The DispensingCompoundingVault.sol contract combines the functionalities of both DispensingVault.sol and CompoundingVault.sol. Users can benefit from both gradual dispensing and compounding yields, providing a balanced approach to managing their investments.


### Compounding Investments
For compounding investments, use the CompoundingVault.sol contract. This contract will automatically reinvest your yields, maximizing your returns over time.

### Dispensing Investments
To set up a schedule for dispensing your investments, use the DispensingVault.sol contract. You can define the schedule and amount to be dispensed at each interval.

### Transferring to Off-Chain Vaults
The protocol supports transferring assets to off-chain vaults to capture yields across different chains. Use the Messenger.sol contract to facilitate these transfers and ensure smooth communication between on-chain and off-chain components.

## Contributing
The project is still ongoing development. We welcome contributions from the community! If you have any ideas, suggestions, or bug reports, please open an issue or submit a pull request. Make sure to follow our contribution guidelines.

## License
This project is licensed under the MIT License. 