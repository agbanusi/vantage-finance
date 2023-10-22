# Vantage Finance - Decentralized Cross-Chain Asset Management

Vantage Finance is a decentralized application (dApp) that allows users to manage and monitor their assets across different blockchain networks. With the Asset Manager, users can seamlessly rebalance, compounding their investments, invest, and monitor their assets while enjoying the benefits of cross-chain transfers of tokens and investments for profit and rebalancing purposes. 

## Table of Contents

- [Vantage Finance - Decentralized Cross-Chain Asset Management](#vantage-finance---decentralized-cross-chain-asset-management)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Usage](#usage)
    - [Smart Contracts](#smart-contracts)
    - [Updating User Profiles](#updating-user-profiles)
    - [HyperLane](#hyperlane)
    - [ChainLink Integration](#chainlink-integration)
    - [Supported Chains](#supported-chains)
    - [Supported Protocols and Investments:](#supported-protocols-and-investments)
    - [Improvements for coming weeks:](#improvements-for-coming-weeks)

## Features

- **Cross-Chain Asset Management**: Easily manage and rebalance your assets across different blockchain networks.

- **User Profile**: Create and maintain user profiles to track the value, investments, withdrawals, and debt related to their assets.

- **ChainLink Integration**: Utilize ChainLink Price Feeds to get real-time token prices in USD, ensuring accurate asset value tracking.

- **Salary and Retirment Plan**: GEt a portion of your asset valaue every period of time typically monthly as a retirment or saving plan to only withdraw a portion of assets for upkeep.

- **Gas-Efficient Routing**: Utilize the HyperLane GasRouter for efficient transaction routing.

## Getting Started

### Prerequisites

Before getting started, make sure you have the following tools and dependencies installed:

- [Node.js](https://nodejs.org/)
- [npm](https://www.npmjs.com/)

### Installation

1. **Clone the repository**:

   ```markdown
   git clone https://github.com/yourusername/asset-manager.git
   ```

2. **Install project dependencies**:
  ```
    npm install
  ```


### Usage
To use the Asset Manager, follow these steps:

1. Deploy the Smart Contracts.
2. Configure and set up your User Profile.
3. Start managing and monitoring your assets across different blockchain networks.


### Smart Contracts
The Asset Manager consists of the following smart contracts:

1. User Profile: Manages user profiles and asset data.
2. HyperLane: Provides gas-efficient cross-chain communication capabilities.
3. ChainLink Integration: Integrates ChainLink Price Feeds for accurate asset valuation and cross chain transfer.
4. User Profile: The User Profile smart contract tracks and manages user assets and values across chains. Users can update their profiles, track asset values, and receive real-time updates on their asset status.
5. Basic Vault: This Vault is majorly for saving tokens or invesment tokens for a future date.
6. Compounding Vault: To force growth of asset, the compounding vault, withdraws all reward and reinvests the as capital to increase capital and eventually ROI.
7. Dispensing Vault: This is to reduce liquiddation of assets and allow a set amount to be dispensed to user every set period to take care of real world needs and reduce interaction with contracts.
8. Compounding + Dispensing Vault: This does both features above.

### Updating User Profiles
Users profiles are updated by vault contracts calling the updateUserProfile function and based on added value, withdrawals, and debt related to their assets.


### HyperLane
HyperLane is a critical component for efficient cross chain communication routing, ensuring that asset management is seamless and gas-efficient.

### ChainLink Integration
ChainLink is integrated to provide accurate asset valuations by utilizing ChainLink Price Feeds and also to allow cross chain movement of tokens or investments lps

### Supported Chains
1. Scroll chain: This is the parent chain containing the User Profile, and ChainLink contracts. All Vault contracts are also deployed on the chain
2. Polygon and ZKEVM: This chains would house another set of Vault Contracts for tokens and Invesments native to these chains.
3. Mantle: This chain would also house another set of Vault Contracts for tokens and Invesments native to Mantle chain.
4. Ethereum: This chain would also house another set of Vault Contracts for tokens and Invesments native to Ethereum chain.
5. Arbitrum: This chain would also house another set of Vault Contracts for tokens and Invesments native to Arbitrum chain.

### Supported Protocols and Investments:
1. Spark SDAI Deposit and Withdrawals with compounding and dispensing features on Vault, allowing users to save their SDAI and compound rewards at every set time period. SDAI is also the major token for rebalancing allowing users to sell or buy a portion of their token with SDAI for portfolio rebalancing and rewards dispensing.
2. Compound: LP tokens from compound are supported
3. Uniswap: The major platform for the selling and buying of tokens using SDAI and USDT.

### Improvements for coming weeks:
1. add deposit and withdrawal fees
2. complete integration to frontend
3. deployments on all needed chains