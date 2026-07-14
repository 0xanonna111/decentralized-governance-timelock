# Decentralized Governance Timelock

An expert-level, secure governance framework enabling decentralized autonomous organizations (DAOs) to propose, vote on, and execute execution payloads on-chain. The system uses a specialized ERC20 governance token with historical checkpoint tracking to prevent flash-loan voting manipulation, coupled with a mandatory execution delay.

## Features
- **Checkpoint-Based Voting Power:** Mitigates flash-loan attacks by referencing historical block weights.
- **Timelock Execution Safeguards:** Enforces a protective cooling-off delay between proposal passing and execution.
- **Dynamic Proposal Lifecycle:** Tracks states seamlessly from creation, active voting, queueing, to terminal execution.

## Getting Started

1. Install dependencies:
   ```bash
   npm install
