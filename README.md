# TokenDrip Distribution Contract

A Clarity smart contract for Stacks blockchain that enables token distribution campaigns with robust safety features.

## Overview

TokenDrip is a flexible distribution system that allows project owners to set up custom token distribution campaigns with granular control over:

- Distribution amounts
- Recipient qualification
- Distribution timeframes
- Security controls

## Features

- **Recipient Management**: Add/remove recipients from an approved list
- **Custom Allocation**: Set different distribution amounts for different recipients
- **Timeframe Control**: Set and update distribution periods
- **Safety Mechanisms**: 
  - Token validation
  - Amount validation
  - Recipient verification
  - Emergency recovery functions
- **Transparency**: Public read functions for distribution status

## Requirements

- Stacks blockchain
- A SIP-010 compliant fungible token

## Contract Functions

### Admin Functions

| Function | Description |
|----------|-------------|
| `set-token-address` | Configure the token to be distributed |
| `initialize-distribution` | Set up distribution parameters |
| `add-to-approved-list` | Add a recipient to the approved list |
| `remove-from-approved-list` | Remove a recipient from the approved list |
| `set-qualified-amount` | Set distribution amount for a specific recipient |
| `end-distribution` | End the distribution campaign |
| `update-distribution-timeframe` | Update the distribution end time |
| `emergency-token-recovery` | Recover tokens in case of emergency |

### User Functions

| Function | Description |
|----------|-------------|
| `receive-distribution` | Claim tokens from the distribution |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-distribution-status` | Check how much a recipient has received |
| `get-token-address` | Get the current token contract address |
| `is-qualified` | Check if an address is qualified for distribution |
| `get-admin` | Get the admin address |
| `is-approved` | Check if an address is on the approved list |
| `get-distribution-info` | Get information about the current distribution |

## Usage Example

```clarity
;; Initialize the distribution
(contract-call? .tokendrip initialize-distribution u1000000 u1000 u1000)

;; Set token address
(contract-call? .tokendrip set-token-address .my-token)

;; Add recipient to approved list
(contract-call? .tokendrip add-to-approved-list 'STNHKEPYEPJ8ET55ZZ0M5A34J0R3N5FM2CMMMAZ6)

;; Set qualified amount for recipient
(contract-call? .tokendrip set-qualified-amount 'STNHKEPYEPJ8ET55ZZ0M5A34J0R3N5FM2CMMMAZ6 u5000)
```

As a recipient:
```clarity
;; Receive tokens from the distribution
(contract-call? .tokendrip receive-distribution .my-token)
```

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized |
| u101 | Already received |
| u102 | Not qualified |
| u103 | Incorrect amount |
| u104 | Insufficient funds |
| u105 | Distribution inactive |
| u106 | Token undefined |
| u107 | Unrecognized token |
| u108 | Invalid quantity |
| u109 | Invalid timeframe |
| u110 | Invalid recipient |

