# Economic model

All amounts use integer token units; values and compute use 18 decimals. BPS denominator is 10,000.

## Fixed values

| Rule | Value |
| --- | --- |
| ALP maximum supply | 210,000,000 ALP |
| Position composition | 50% partner asset / 50% USDT |
| USDT allocation | 50% reward treasury / 50% liquidity |
| Day 1 output rate | 60 BPS (0.60%) |
| Daily output increase through day 60 | 1 BPS |
| Day 60 onward output rate | 120 BPS (1.20%) |
| Daily burn rate | 120 BPS (1.20%) |
| ALP sell protocol fee | 1,700 BPS (17%) |

For a position value `V`, partner-token price `P`, and 18-decimal value convention:

`partnerAmount = (V * 5,000 / 10,000) / P`

`usdtContribution = V * 5,000 / 10,000`

`rewardTreasury = usdtContribution * 5,000 / 10,000`

`liquidityAllocation = usdtContribution - rewardTreasury`

The subtraction in the final allocation preserves every rounding remainder.

At epoch `n`, based on ALP balance in `MainPair` before settlement:

`burn = pairAlpBalance * 120 / 10,000`

`emission = pairAlpBalance * outputRate(n) / 10,000`

`outputRate(n) = 60 + (n - 1) BPS` for days 1–59, then `120 BPS` from day 60 onward.

The supplied commercial rules specify both a 1-BPS daily increase and a 120-BPS day-60 rate; those two statements are off by 1 BPS when counting day 1 inclusively. The implementation honors the explicitly fixed day-60 120-BPS value. This schedule must receive governance/legal sign-off before mainnet deployment.

The global reward index increases once per emission:

`accRewardPerCompute += emission * 1e27 / globalEffectiveCompute`

A position's pending ALP is `effectiveCompute * accRewardPerCompute / 1e27 - rewardDebt`.

For default linear compensation after `d` whole days:

`factor = 1e18 + d * 1e16`

`effectiveCompute = baseCompute * factor / 1e18`

Compound compensation exists as a selectable strategy but is not enabled by the default V1 pool.

## Sell fee split

The 1,700 BPS fee is conserved as 500 BPS buyback, 100 BPS Top100, 400 BPS node/airdrop, 500 BPS community, and 200 BPS development. The seller transfer is `amount - fee`; all remainder handling stays with the seller amount so no ALP is lost to rounding.

## Items intentionally configurable

Referral USDT/compute split, node-dividend funding source, Top100 ranking strategy, non-CARD vault policy, and compensation strategy must be set by governance. Production mode rejects incomplete configuration.
