# Decentralized Crowdfunding Platform

A smart contract-based crowdfunding platform built with Solidity that enables trustless campaign creation, pledge pooling, and conditional fund distribution on the Ethereum blockchain. Implements the pull payment pattern for scalable refunds and includes comprehensive reentrancy protection.

## Overview

This project implements a Kickstarter-style crowdfunding platform where creators launch funding campaigns with specific goals and deadlines, backers pledge funds that are held in escrow, and money is either released to creators (if goal met) or refunded to backers (if goal not met) after the deadline passes. The platform takes a 3% fee on successful campaigns.

## Features

### Core Functionality

**Campaign Management**

- Creators launch campaigns with title, description, funding goal, and deadline
- Each campaign receives a unique ID via counter-based system
- Campaigns have status tracking: Active, Successful, Failed, Cancelled
- Minimum goal requirement of 0.1 ETH to prevent spam
- String length validation (title 1-100 chars, description 1-500 chars)
- Deadline validation ensures all campaigns have future completion dates
- Creators can cancel their own campaigns before deadline

**Pledge System**

- Backers pledge any amount to active campaigns
- Multiple pledges from same backer automatically accumulate
- Individual pledge amounts tracked per backer per campaign
- Total pledged amount aggregated in campaign struct for efficiency
- Pledges held securely in contract escrow until finalization
- Can only pledge to Active status campaigns

**Campaign Finalization**

- Anyone can finalize a campaign after deadline passes (decentralized approach)
- Automatic status determination based on total pledged vs goal amount
- If total pledged >= goal: Status becomes Successful
- If total pledged < goal: Status becomes Failed
- Finalization can only occur once per campaign
- Cannot finalize before deadline

**Fund Distribution**

- Pull payment pattern: Participants claim their own funds
- Successful campaigns: Creator withdraws funds minus 3% platform fee
- Failed campaigns: Each backer claims their full pledge back
- Cancelled campaigns: Backers claim refunds (treated like failed campaigns)
- Double-withdrawal prevention via tracking flags and pledge reset
- Reentrancy protection using Checks-Effects-Interactions pattern

**Pledge Withdrawal**

- Backers can withdraw their pledge before the deadline
- Withdrawal reduces both individual pledge and campaign total
- Cannot withdraw after deadline passes (must wait for finalization)
- Automatic state updates after withdrawal
- Only works for Active campaigns

**Early Cancellation**

- Creators can cancel campaigns before deadline
- Cancelled campaigns enable backer refunds via claimPledge
- Cannot cancel after deadline (must go through finalization)
- Sets campaign to finalized state to prevent further pledges

### Security Features

- Reentrancy protection via CEI pattern (Checks-Effects-Interactions)
- Double-withdrawal prevention for both creators and backers
- Exact pledge tracking per backer to prevent over-refunding
- Access control on sensitive operations (only creator can cancel/withdraw)
- State reset before ETH transfers to prevent exploit attempts
- Validation at every state transition

## Technical Details

### Smart Contract Structure

**Enums**

```solidity
enum Status { Active, Successful, Failed, Cancelled }
```

**Structs**

- `Campaign`: Stores campaign data (id, creator, title, description, goalAmount, totalPledged, deadline, status, fundsWithdrawn, isFinalised)

**Key Mappings**

- `campaigns`: Maps campaign ID to Campaign struct
- `pledges`: Nested mapping tracking individual pledges (campaignId => backer address => amount)

**Modifiers**

- `OnlyCreator`: Restricts function access to campaign creator

**Core Functions**

```solidity
createCampaign(string _title, string _description, uint256 _goalAmount, uint256 _deadline)
pledge(uint256 _campaignId) payable
finaliseCampaign(uint256 _campaignId)
distributeFunds(uint256 _campaignId)
cancelCampaign(uint256 _campaignId)
claimPledge(uint256 _campaignId)
withdrawPledge(uint256 _campaignId)
```

**Helper Functions**

- `refundBacker(uint256 _campaignId)`: Private function handling refund logic with reentrancy protection

### Payment Flow

1. **Campaign Creation**: Creator posts campaign with goal and deadline
2. **Pledge Phase**: Backers send ETH to contract (held in escrow)
3. **Finalization**: After deadline, anyone triggers finalization
4. **Distribution**:
   - Successful: Creator calls distributeFunds to claim 97% (3% to platform owner)
   - Failed: Each backer calls distributeFunds to claim their full pledge back
   - Cancelled: Each backer calls claimPledge to retrieve their pledge

### Reentrancy Protection

The contract implements the Checks-Effects-Interactions (CEI) pattern to prevent reentrancy attacks:

```solidity
function refundBacker(uint256 _campaignId) private {
    // 1. CHECKS (already validated by calling function)
    uint256 refundAmount = pledges[_campaignId][msg.sender];

    // 2. EFFECTS (update state first)
    pledges[_campaignId][msg.sender] = 0;
    campaigns[_campaignId].totalPledged -= refundAmount;

    // 3. INTERACTIONS (external call last)
    (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
    require(success, "ETH not transferred to backer correctly.");
}
```

This ensures state changes occur before external calls, preventing malicious contracts from re-entering and draining funds.

### Fee Calculation

Platform fees are calculated using integer arithmetic:

```solidity
uint256 platformFee = (totalPledged * 3) / 100;  // 3% fee
uint256 creatorAmount = totalPledged - platformFee;  // 97% to creator
```

### Pull Payment Pattern

Rather than pushing refunds to all backers (which doesn't scale and risks hitting gas limits), the contract implements pull payments where each participant claims their own funds:

**Advantages:**

- Scales to any number of backers
- Each user pays gas for their own withdrawal
- No risk of transaction failure due to large backer count
- Backers control timing of their refund claims
- Standard pattern in production DeFi applications

## Usage

### Deployment

1. Compile with Solidity compiler version ^0.8.0
2. Deploy to preferred network (testnet recommended for testing)
3. Deployer becomes platform owner and receives platform fees
4. No constructor parameters required

### Creating a Campaign

```solidity
// Create campaign with 5 ETH goal, 30-day deadline
uint256 deadline = block.timestamp + 30 days;
createCampaign(
    "Community Center Renovation",
    "Help us renovate our local community center to serve 500+ families",
    5000000000000000000,  // 5 ETH in wei
    deadline
);
```

### Pledging to a Campaign

```solidity
// Pledge 1 ETH to campaign #1
pledge(1); // Send 1000000000000000000 wei as msg.value
```

### Finalizing a Campaign

```solidity
// Anyone can call this after deadline passes
finaliseCampaign(1);
```

### Claiming Funds

**For Successful Campaigns (Creator):**

```solidity
// Creator calls this to receive 97% of funds
distributeFunds(1);
```

**For Failed Campaigns (Backers):**

```solidity
// Each backer calls this to get their pledge back
distributeFunds(1);
```

**For Cancelled Campaigns (Backers):**

```solidity
// Each backer calls this to claim refund
claimPledge(1);
```

### Withdrawing Pledge Early

```solidity
// Backer withdraws before deadline
withdrawPledge(1);
```

### Cancelling a Campaign

```solidity
// Only creator, only before deadline
cancelCampaign(1);
```

## Events

The contract emits events for off-chain tracking and UI updates:

- `NewCampaign(uint256 campaignId)`
- `NewPledge(uint256 campaignId, uint256 amount)`
- `CampaignFinalised(uint256 campaignId)`
- `FundsDistributed(uint256 campaignId)`
- `CancelledCampaign(uint256 campaignId)`
- `RefundIssued(uint256 campaignId, uint256 amount)`

## Testing Scenarios

1. **Successful Campaign Flow**: Create campaign, pledge enough to meet goal, finalize, creator withdraws
2. **Failed Campaign Flow**: Create campaign, pledge less than goal, finalize, backers claim refunds
3. **Multiple Backers**: Multiple addresses pledge to same campaign, verify individual tracking
4. **Early Withdrawal**: Backer pledges then withdraws before deadline, verify totals update
5. **Cancellation Flow**: Creator cancels before deadline, backers claim refunds
6. **Double-Claim Prevention**: Attempt to claim refund twice (should fail on second attempt)
7. **Double-Withdrawal Prevention**: Creator tries to withdraw twice (should fail)
8. **Premature Finalization**: Try to finalize before deadline (should fail)
9. **Platform Fee Calculation**: Verify 3% deduction on successful campaigns
10. **Access Control**: Non-creator tries to cancel/withdraw (should fail)
11. **Status Transitions**: Verify correct status changes throughout campaign lifecycle

## Design Patterns

### Escrow Pattern

The contract acts as a trusted intermediary holding pledge funds until campaign outcome is determined, eliminating need for direct backer-to-creator trust.

### Pull Payment Pattern

Rather than pushing payments to all participants, the contract allows each participant to pull their own funds, enabling better scalability and gas efficiency.

### State Machine

Campaigns transition through defined states (Active → Successful/Failed/Cancelled) with validation at each transition point.

### Checks-Effects-Interactions (CEI)

Critical security pattern ensuring state updates occur before external calls to prevent reentrancy attacks.

### Aggregate Data Tracking

Storing totalPledged in the Campaign struct alongside individual pledges enables O(1) goal checking without expensive iteration.

## Security Considerations

### Addressed Vulnerabilities

**Reentrancy**

- State updated before ETH transfers in all refund functions
- Pledge amounts reset to 0 before sending to prevent re-entry

**Double-Spending**

- fundsWithdrawn flag prevents creator from withdrawing multiple times
- Pledge reset prevents backers from claiming refunds multiple times

**Access Control**

- Only campaign creator can cancel or withdraw from successful campaigns
- Only backers with pledges can claim refunds
- Only finalized campaigns allow fund distribution

**Integer Overflow**

- Using Solidity ^0.8.0 which has built-in overflow protection

### Known Limitations

- Platform fee hardcoded at 3% (could be made configurable)
- No partial refunds or milestone-based releases
- Campaign details cannot be edited after creation
- No reputation system for creators or success rate tracking
- Platform fees accumulate in contract without withdrawal mechanism for owner
- No dispute resolution mechanism between creators and backers

## Development Environment

- **Language**: Solidity ^0.8.0
- **License**: MIT
- **Recommended IDE**: Remix IDE for prototyping and testing
- **Testing Network**: Ethereum testnets (Sepolia, Goerli)
- **Tools**: Compatible with Hardhat and Foundry for advanced testing

## Future Enhancements

**Security Improvements**

- Implement ReentrancyGuard from OpenZeppelin for additional protection layer
- Add pause functionality for emergency stops
- Implement withdrawal mechanism for accumulated platform fees
- Add time-locks on critical operations

**Feature Additions**

- Milestone-based funding with partial releases
- Reward tiers for different pledge levels (NFT rewards, perks)
- Campaign categories and tagging system
- Creator reputation tracking based on past campaign outcomes
- Deadline extension requests (with backer approval mechanism)
- Campaign updates and communication channel
- Stretch goals for campaigns exceeding initial target
- Refund voting mechanism for disputed campaigns

**Gas Optimizations**

- Pack struct variables for storage efficiency
- Implement batch operations for common workflows
- Optimize string storage strategies

**User Experience**

- Allow pledge amount updates before deadline
- Enable partial pledge withdrawals
- Add campaign search and discovery features
- Support multiple payment tokens (stablecoins)

## Comparison to Traditional Crowdfunding

**Advantages:**

- Trustless escrow (funds held by smart contract, not platform)
- Transparent fund tracking (all pledges visible on blockchain)
- Automatic refunds (no manual processing required)
- Lower platform fees (3% vs 5-10% on traditional platforms)
- Censorship resistant (campaigns cannot be arbitrarily removed)
- Global accessibility (anyone with wallet can participate)

**Trade-offs:**

- Requires cryptocurrency and wallet setup
- Gas fees for all transactions
- Irreversible transactions (limited dispute resolution)
- Smart contract risk (bugs could lock funds)
- Less user-friendly for non-crypto users
