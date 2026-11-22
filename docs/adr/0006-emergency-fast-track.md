# 0006: Emergency fast track and the 20 percent cap

Status: Accepted

## Context

In disaster response (earthquakes, flash floods, wildfires), aid workers and relief agencies require immediate liquidity within the first hours to purchase food, water, medical supplies, and temporary shelter. 

Under the standard milestone model, funds are only released after milestone deliverables are completed and verified with proof URIs. Waiting for milestone execution before disbursing any funds severely impairs urgent humanitarian intervention. However, releasing unverified funds creates substantial risk of fraud or capital loss.

## Decision

Enable an emergency advance mechanism (`emergency_fast_track`) for campaigns designated as `CampaignKind::Emergency`, governed by specific safety guardrails:

1. **Strict 20% cap on total goal:** The advance amount is bounded to at most 20% of the campaign's total goal:
   ```
   cap = campaign.goal * 2000 / 10000
   advance = min(cap, campaign.raised - campaign.released)
   ```
   Limiting the advance to 20% balances immediate disaster response liquidity against donor capital risk.
2. **Sole authorization by the verifier:** Only the campaign's registered verifier (`campaign.verifier.require_auth()`) can execute `emergency_fast_track`. Campaign creators and beneficiaries cannot trigger the advance themselves. Because verifiers hold staked bonds and are vetted by the admin, they act as independent guardians who confirm disaster urgency before disbursing funds.
3. **Single advance rule:** The advance can only be invoked once per campaign (`emergency_advance == 0`). Once triggered, subsequent payouts must follow the regular milestone approval flow backed by verifiable evidence.
4. **Milestone accounting:** The advance is credited against milestone 0 (`milestones[0]`). When the verifier later approves milestone 0 via `approve_milestone`, the contract transfers only the remaining balance (`milestones[0] - emergency_advance`), ensuring the total payout for milestone 0 never exceeds its target.
5. **Interaction with donor refunds:** The advance immediately increments `campaign.released`. Because donor refunds are computed as:
   ```
   refund = contribution * (raised - released) / raised
   ```
   The disbursed advance reduces the refundable pool. Funds released under the emergency advance are treated as irrevocably deployed relief aid. If the campaign is subsequently cancelled or expires, donors receive their pro-rata share of the remaining escrow (`raised - released`).

## Consequences

- First responders gain rapid access to capital during critical disaster windows without waiting for formal proof submission.
- The 20% ceiling bounds maximum donor exposure prior to verified deliverables.
- Verifier authorization prevents creators from deploying malicious campaigns and draining escrow immediately.
- Donors accept that up to 20% of their contributions may be disbursed as emergency relief and excluded from potential refunds if the campaign is cancelled early.

## Alternatives considered

- **Permitting creator-initiated advances:** Allowing creators to withdraw upfront capital creates high rug-pull risk for disaster campaigns.
- **Higher advance caps (e.g., 50% or 100%):** Exposes too much donor capital to unverified deployment before any accountability is established.
- **Multiple partial fast-track advances:** Increases state complexity and accounting edge cases compared to a single bounded advance against milestone 0.
- **Advance clawback on cancellation:** Attempting to force beneficiaries to return deployed emergency funds on-chain is impossible once tokens leave contract escrow.
