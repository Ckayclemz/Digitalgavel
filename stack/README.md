# DigitalGavel NFT Marketplace Smart Contract

## Overview

DigitalGavel is a secure, decentralized NFT marketplace smart contract built on the Stacks blockchain. It provides a transparent and efficient platform for creating, bidding on, and concluding NFT auctions.

## Features

- Create NFT marketplace listings
- Place bids on listed NFTs
- Secure fund and NFT transfers
- Configurable auction parameters
- Built-in safety checks and validations

## Contract Architecture

### Main Functions

1. **`create-listing`**
   - Creates a new NFT marketplace listing
   - Requires NFT ownership verification
   - Sets reserve price and auction duration

2. **`place-bid`**
   - Submit bids on active listings
   - Automatic refund of previous highest bids
   - Enforces minimum bid requirements

3. **`conclude-listing`**
   - Finalize the auction
   - Transfer NFT to highest bidder or return to seller
   - Distribute auction funds

### Key Security Mechanisms

- Input parameter validation
- Ownership and contract verification
- Bid and listing integrity checks
- Secure fund and NFT transfers

## Contract Parameters

- **Minimum Bid**: 1,000,000 microSTX
- **Maximum Listing Duration**: 30 days
- **Listing Limit**: 1000 concurrent listings

## Error Handling

The contract provides detailed error codes for various scenarios:
- Unauthorized actions
- Invalid listing parameters
- Auction status conflicts
- Bid validation failures

## Usage Example

### Creating a Listing

```clarity
(contract-call? .digitalgavel create-listing 
    nft-contract-principal 
    token-id 
    reserve-price 
    auction-duration)
```

### Placing a Bid

```clarity
(contract-call? .digitalgavel place-bid 
    listing-id 
    bid-amount)
```

### Concluding a Listing

```clarity
(contract-call? .digitalgavel conclude-listing 
    listing-id 
    nft-contract-principal)
```

## Security Considerations

- Always verify NFT contract compatibility
- Ensure sufficient STX balance before bidding
- Be aware of auction expiration times
- Understand the non-refundable nature of bids

## Installation

1. Deploy the smart contract to a Stacks blockchain network
2. Ensure compatibility with NFT contract standards
3. Set initial system parameters
