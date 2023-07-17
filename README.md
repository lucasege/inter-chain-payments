## Inter-chain payments
The purpose of this repo is a proof of concept of a design derived from this talk by [Uma from Succint.xyz](https://www.youtube.com/watch?v=G0nFyq9DDPw&list=PLrTmn1_Dm_UpwHsAAyn3L0f2OZUA02YjC&index=8).

```
This is nowhere near production-level code and should be treated as a hackathon-style proof of concept
```

Succinct is working on a similar design that utilizes a somewhat centralized RPC provider to do the proof of liquidity and transfering of assets. I wanted to take a stab at implementing this using a paymaster from the ERC-4337 Account Abstraction design.

The idea here is that users have one `SourceAccount` on the `Source` chain (probably ETH L1). They would create this SCW `contracts/src/SourceAccount.sol` once and deposit some assets into it. This same user would then perform some actions on a `Remote` chain that would utilize these assets. This would be possible by utilizing the `contracts/src/ReceiverAccount.sol` design which is a 4337-enabled SCW that would create a `UserOperation` with a custom Signature (`contracts/src/InterChainSigData.sol`) that can be verified on both the `Remote` and `Source` chains.

A 3rd-party operator deploys the `InterChainPaymaster` (permissionlessly) which could accept these `UserOperation`s, verify thme on the `Remote` chain and then make a cross-chain call to also verify this on the `Source` chain. This verification verifies that the `UserOp` is valid and also that if this op is executed on the `Remote` chain that the `Paymaster` will be able to pull a rebate from the `Source` chain's vault. This rebate would cover both the assets for the op and some fee to incentivize the paymaster.

This allows users to utilize L1 liquidity without needing to explicitly bridge assets. This removes some UX annoyances (bridges are unwieldy) and reduces the risks associated with using a traditional bridge with all locked funds in a single contract (this is closer to a liquidity network bridge in that sense).

### Current status
* [x] Deploy all contracts on source and remote chains
* [x] Very basic UI to show each contract and allow for deposits and creating user Ops
* [x] Finished UserOp construction on the frontend and verification on both chains under local development (Not using bridging)
* [x] Signing UserOps using Metamask
* [x] Deployed and tested on ETH Goerli L1 (Source) with OP Goerli L2 (Remote)
* [x] Simple PoC of buying an NFT on the remote chain using liquidity from the source chain
* [ ] Fully implement cross-chain mechanism (Axelar bridge to verify all claims)


### Current limitations
* The `SourceAccount` currently isn't really a wallet, it is moreso a vault that can be deposited into but not withdrawn from. This makes the verification logic simpler but is generally less useful. A simple extension would be to add a withdrawal timer, i.e. owners can request a withdraw and receive their assets after a fixed period (to prevent rugging).
* The `SourceAccount` also currently doesn't make the necessary cross-chain verification to see that the `UserOp` was actually executed on the remote chain. This would require another state management contract on the remote chain that tracks executed UserOps and is kind of a hassle.
* The `InterChainPaymaster` currently just calls into the `SourceAccount` to verify a user op but doesn't include the necessary infra to actually check this claim. This will require a round-trip call and some more state management.

### Extensions
* I'd like to implement a simple metamask snap for signing UserOp signatures so that users aren't just blindly signing hex data.
 
At this point the proof of concept has been finished (I have all components working) and so now this is just an exercise in deployment and orchestrating bridges which has taken up too much time so far. Will finish this in the future.

Cross-chain dev + account abstraction makes for a really complex and slow dev cycle.
