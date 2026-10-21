# Base Solaris Crowdfund

A decentralized, milestone-based crowdfunding platform built on the Base network. Solaris empowers creators and startups to raise capital trustlessly, ensuring that backers' funds are protected through smart contract logic rather than centralized promises.

## Core Mechanics
* **All-or-Nothing Funding:** Campaigns must reach their predefined financial target before a specific `block.timestamp` deadline. If the goal is not met, the contract allows backers to instantly withdraw their full pledge.
* **Milestone Releases:** To protect investors from rug-pulls, funds are not released to the creator all at once. The community votes to unlock tranches of capital based on verifiable project milestones.
* **Immutable Campaign Parameters:** Once a campaign is launched, the funding goal, deadline, and milestone structures are mathematically locked in the state and cannot be altered by the creator.

## Architecture & Security
Developed using Solidity `0.8.37`. The protocol heavily utilizes the "Pull over Push" withdrawal pattern. Refunds and milestone payouts require the recipient to actively claim their funds, completely neutralizing malicious contract blockages and reentrancy attacks.
