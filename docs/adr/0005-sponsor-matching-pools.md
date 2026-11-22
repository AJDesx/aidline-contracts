# 0005: Sponsor matching pools

Status: Accepted

## Context

Institutional donors, philanthropic foundations, and corporate sponsors often wish to incentivize individual giving by offering matching funds (e.g., matching $0.50 or $1.00 for every $1.00 donated). 

Without on-chain matching pools, matching requires out-of-band trust or centralized off-chain accounting. The contract needs a trustless mechanism where sponsors commit funds upfront, matching occurs systematically according to transparent mathematical rules, overfunding is strictly prohibited, and unused sponsor funds are safely returned.

## Decision

Introduce dedicated, campaign-scoped sponsor matching pools managed through three entry points: `deposit_sponsor_pool`, `apply_matching`, and `return_sponsor_pool`.

1. **Upfront deposit and capped commitment:** A sponsor commits matching funds by calling `deposit_sponsor_pool(sponsor, campaign_id, ratio_bps, cap, amount)`. The sponsor deposits the full `cap` upfront (`amount == cap`), ensuring funds are guaranteed in escrow. The match ratio is defined in basis points (`ratio_bps`, up to 10,000 for 100% matching). Each sponsor may maintain one active pool per campaign.
2. **Permissionless matching invocation (`apply_matching`):** Anyone (the donor, a relayer, frontend client, or keeper) can call `apply_matching`. Because the sponsor already authorized and deposited the funds, requiring a sponsor signature for every match would create an availability bottleneck whenever the sponsor is offline. The match calculation is purely deterministic: `raw_match = donation_amount * ratio_bps / 10_000`.
3. **Strict adherence to campaign goal:** Matching can never cause a campaign to exceed its fundraising goal. The applied match is clamped:
   ```
   matched_amount = raw_match.min(cap_remaining).min(pool_remaining).min(campaign_headroom)
   ```
   Where `campaign_headroom = campaign.goal - campaign.raised`. This prevents overfunding, preserves milestone accounting invariant `raised <= goal`, and eliminates excess escrow.
4. **Contribution accounting for refunds:** Matched tokens are added to `campaign.raised` and recorded as a contribution under the sponsor's address. If the campaign fails or cancels, the sponsor receives their pro-rata share of unreleased funds through the standard refund mechanism.
5. **Reclaiming unmatched funds:** Once the campaign ends (completed, cancelled, or passed deadline), the sponsor can call `return_sponsor_pool` with their own authorization to withdraw any unmatched balance (`pool.remaining`).

## Consequences

- Sponsors can incentivize grassroots donors without trusting creators or platform intermediaries.
- Matching execution is resilient and cannot be stalled by inactive sponsors.
- Strict clamping against `campaign_headroom` ensures the campaign never raises more than its milestone-backed goal.
- Matching pools lock sponsor capital until the campaign ends; early withdrawal is disallowed while the campaign remains active.
- Unmatched funds remain safe and can always be retrieved by the sponsor after campaign closure.

## Alternatives considered

- **Synchronous matching within `donate`:** Having `donate` automatically pull from all active pools in a single transaction. This was avoided because dynamic loops over multiple sponsor pools in `donate` would create unbounded gas/CPU footprint and vulnerability to denial-of-service if a pool is corrupted or exhausted.
- **Sponsor signature per donation match:** Requiring the sponsor to co-sign every match transaction. This would make matching dependent on sponsor uptime, severely reducing real-time donation UX.
- **Allowing campaigns to exceed goal via matching:** Permitting matching beyond `goal` would break milestone accounting, since milestone releases are structured to sum exactly to `goal`.
- **Slashing or forfeiting unused sponsor pools:** Forfeiting unmatched capital would severely discourage institutional participation.
