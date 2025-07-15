# Splitoshi NFT Fractionalization Contract

Splitoshi is a smart contract built on the Stacks blockchain using Clarity that allows users to split expensive NFTs into smaller, tradeable shares. This enables fractional ownership of high-value NFTs, making them more accessible to a broader audience.

## 🚀 Features

- **NFT Fractionalization**: Split any NFT into a custom number of shares
- **Share Trading**: Direct peer-to-peer transfer of shares between users
- **Built-in Marketplace**: List and buy shares using STX tokens
- **NFT Redemption**: Reclaim the original NFT by collecting all shares
- **Secure Ownership**: Comprehensive ownership verification and authorization
- **Trait-based Design**: Compatible with any NFT contract that implements the required interface

## 📋 Contract Overview

### Core Functionality

1. **Vault Creation**: Users deposit an NFT and specify how many shares to create
2. **Share Management**: Transfer shares between users or list them for sale
3. **Marketplace**: Buy and sell shares with automatic STX payments
4. **Redemption**: Reunite all shares to reclaim the original NFT

### Data Structures

- **Vaults**: Store NFT information and fractionalization details
- **User Shares**: Track individual share ownership
- **Share Listings**: Manage marketplace listings with pricing

## 🛠️ Installation & Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Stacks CLI](https://docs.stacks.co/docs/write-smart-contracts/cli-wallet-quickstart) - For deployment

### Setup

1. Clone or create a new Clarinet project:
```bash
clarinet new splitoshi-project
cd splitoshi-project
```

2. Add the contract to your `contracts/` directory:
```bash
# Copy splitoshi.clar to contracts/splitoshi.clar
```

3. Verify the contract compiles:
```bash
clarinet check
```

4. Run tests:
```bash
clarinet test
```

## 📖 Usage Guide

### Creating a Vault

To fractionalize an NFT, call the `create-vault` function:

```clarity
(contract-call? .splitoshi create-vault 
  .my-nft-contract    ;; NFT contract implementing the trait
  u1                  ;; NFT ID
  u1000              ;; Total shares to create
  "My Expensive NFT"  ;; Vault name
)
```

### Transferring Shares

Send shares directly to another user:

```clarity
(contract-call? .splitoshi transfer-shares 
  u1                    ;; Vault ID
  u100                  ;; Number of shares
  'SP1234...RECIPIENT   ;; Recipient address
)
```

### Listing Shares for Sale

List shares on the marketplace:

```clarity
(contract-call? .splitoshi list-shares-for-sale 
  u1      ;; Vault ID
  u100    ;; Shares to sell
  u1000   ;; Price per share (in microSTX)
)
```

### Buying Shares

Purchase shares from a listing:

```clarity
(contract-call? .splitoshi buy-shares 
  u1                  ;; Vault ID
  'SP1234...SELLER    ;; Seller address
  u50                 ;; Number of shares to buy
)
```

### Redeeming NFT

Collect all shares to reclaim the original NFT:

```clarity
(contract-call? .splitoshi redeem-nft 
  u1                ;; Vault ID
  .my-nft-contract  ;; Original NFT contract
)
```

## 🔍 Read-Only Functions

### Get Vault Information
```clarity
(contract-call? .splitoshi get-vault-info u1)
```

### Check User Shares
```clarity
(contract-call? .splitoshi get-user-shares u1 'SP1234...USER)
```

### View Share Listing
```clarity
(contract-call? .splitoshi get-share-listing u1 'SP1234...SELLER)
```

## 🛡️ Security Features

- **Ownership Verification**: Ensures only NFT owners can create vaults
- **Share Validation**: Prevents invalid share transfers and operations
- **Authorization Checks**: Comprehensive permission system
- **Safe Math**: Prevents overflow and underflow vulnerabilities
- **Atomic Operations**: All operations complete fully or revert

## ⚠️ Error Codes

| Code | Error | Description |
|------|--------|-------------|
| u100 | ERR_NOT_AUTHORIZED | User lacks permission for operation |
| u101 | ERR_INVALID_SHARES | Invalid share amount (zero or negative) |
| u102 | ERR_VAULT_NOT_FOUND | Vault doesn't exist |
| u103 | ERR_INSUFFICIENT_SHARES | Not enough shares for operation |
| u104 | ERR_VAULT_ALREADY_EXISTS | Vault ID already in use |
| u105 | ERR_INVALID_PRICE | Invalid price (zero or negative) |
| u106 | ERR_ALREADY_LISTED | Shares already listed for sale |
| u107 | ERR_NOT_LISTED | No active listing found |
| u108 | ERR_INSUFFICIENT_PAYMENT | Payment amount too low |
| u109 | ERR_NFT_TRANSFER_FAILED | NFT transfer unsuccessful |

## 🏗️ NFT Contract Requirements

To work with Splitoshi, NFT contracts must implement the following trait:

```clarity
(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)
```

### Example NFT Contract Integration

```clarity
;; Your NFT contract should implement these functions:
(define-public (transfer (id uint) (sender principal) (recipient principal))
  ;; Transfer logic here
)

(define-read-only (get-owner (id uint))
  ;; Return owner logic here
)
```

## 🧪 Testing

### Unit Tests

Create test files in the `tests/` directory:

```typescript
// tests/splitoshi_test.ts
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create vault with valid NFT",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('splitoshi', 'create-vault', [
                types.principal('ST1234...NFT-CONTRACT'),
                types.uint(1),
                types.uint(1000),
                types.ascii("Test Vault")
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
    }
});
```

### Running Tests

```bash
clarinet test
```

## 🚀 Deployment

### Local Deployment

1. Start local Stacks node:
```bash
clarinet integrate
```

2. Deploy contract:
```bash
clarinet deploy --network=testnet
```

### Mainnet Deployment

1. Configure your `Clarinet.toml`:
```toml
[network.mainnet]
node_rpc_api = "https://stacks-node-api.mainnet.stacks.co"
```

2. Deploy to mainnet:
```bash
clarinet deploy --network=mainnet
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Write tests for new functionality
4. Ensure all tests pass: `clarinet test`
5. Submit pull request

## 🏆 Use Cases

### Art Collections
- Fractionalize expensive digital art
- Enable community ownership of masterpieces
- Create liquid markets for illiquid assets

### Gaming Assets
- Split rare in-game items
- Enable fractional ownership of virtual land
- Create new trading opportunities

### Real Estate NFTs
- Fractionalize property-backed NFTs
- Enable small investors to participate
- Create diverse investment portfolios

### Collectibles
- Share ownership of rare collectibles
- Enable price discovery for unique items
- Create new revenue streams for creators

**Built with ❤️ for the Stacks ecosystem**