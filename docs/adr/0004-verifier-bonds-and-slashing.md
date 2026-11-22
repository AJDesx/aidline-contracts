# 0004: Verifier bonds and slashing

Status: Accepted

## Context

In the initial design, verifiers approved milestones without putting capital at risk. If a verifier approved fraudulent milestones, colluded with a malicious creator, or failed to perform due diligence, donors lost their funds while the verifier suffered no financial penalty.

To secure donor contributions, the system requires an economic deterrent against dishonesty and negligence, a mechanism to penalize bad actors, and a way to hold exit funds until fraud can be investigated.

## Decision

Require verifiers to stake an upfront bond via `register_with_bond` before they can approve milestones.

1. **Staking requirement:** Verifiers deposit at least `bond_requirement` into contract escrow upon registration. The bond remains locked while the verifier is active.
2. **Delayed withdrawal:** When a verifier deregisters via `deregister_verifier`, the bond enters `PendingWithdrawal` and cannot be withdrawn via `withdraw_bond` until `bond_withdraw_delay` seconds have elapsed. This challenge window allows the admin and community time to detect fraud, audit milestone releases, and initiate slashing before capital leaves the contract.
3. **Restorative slashing for donors:** If a verifier approves fraudulent milestones or breaches duty, the admin can call `slash_verifier(verifier, campaign_id, slash_amount)`. Slashed tokens are transferred directly into the affected campaign's balance: `campaign.raised` is credited and the contract address is recorded as a contributor. When donors claim refunds via `refund`, the contract's pro-rata refund formula automatically routes the recovered bond tokens back to the affected donors.

## Consequences

- Verifiers have direct skin in the game, aligning their incentives with donors.
- Verifiers must lock capital, which increases onboarding friction.
- The withdrawal delay prevents malicious verifiers from approving bad milestones and immediately withdrawing their bond before the compromise is noticed.
- Slashed funds compensate affected donors directly through existing refund logic without creating new refund registries or claims pools.
- Admin trust is required to trigger slashing fairly and without abuse.

## Alternatives considered

- **Token burning:** Burning slashed tokens penalizes dishonest verifiers but leaves defrauded donors uncompensated.
- **Protocol treasury redirection:** Sending slashed tokens to the admin or a DAO treasury creates perverse incentives to slash honest verifiers for protocol revenue.
- **Immediate bond withdrawal upon deregistration:** Allows a colluding verifier to approve a fraudulent milestone and extract their bond before donors or the admin can react.
- **Per-campaign bonding:** Requiring verifiers to post separate bonds for every campaign they verify fragments liquidity and restricts verifiers from scaling across multiple campaigns.
