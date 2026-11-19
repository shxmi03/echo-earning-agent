# Pricing

Reads `replica/fixes.md` (fixes 1 and 2), `replica/feedback.md` and `replica/architecture.md` (StoreKit 2, iOS only). Date: 2026-11-19.

**Proposal: one free course, then one plan in two sizes. Solo at $9.99 a month or $99.99 a year. Household (up to 5 learners) at $14.99 a month or $149.99 a year. The same 7-day trial on monthly and yearly.** All of it is a proposal; the prices are yours to set.

## The market, read today

US App Store in-app purchase lists, read 2026-11-19. Apple's page lists names and prices but not the billing period, so the period column is my reading of the price, marked "likely". Check each one in the app's own paywall before quoting it anywhere.

| app | URL | prices listed (USD) | likely monthly | likely yearly | family |
| --- | --- | --- | --- | --- | --- |
| The original | https://apps.apple.com/us/app/simply-piano-learn-piano-fast/id1019442026 | 149.99, 24.95, 119.99 ×3, 34.95, 179.99, 74.99, 95.99, 19.99 | $24.95 | $119.99 to $149.99 (one $95.99 "20% off" offer) | $34.95 a month (likely) or $179.99 a year |
| flowkey | https://apps.apple.com/us/app/flowkey-learn-to-play-piano/id1020357408 | 119.99 ×3, 19.99, 149.99, 179.99, 24.99, 38.99, 29.99, 139.99 | $19.99 to $29.99 | $119.99 to $179.99 | not listed |
| Skoove | https://apps.apple.com/us/app/skoove-learn-to-play-piano/id1160668178 | 149.99, 89.99, 29.99, 19.99, 59.99, 119.99, 39.99, 9.99, 59.99, 4.99 | $19.99 to $29.99 | $89.99 to $149.99 | not listed |

Not read: Playground Sessions (its pricing page needs a login), Google Play (out of scope, iOS only).

What the table says: the category sits at about **$20-30 a month and $120-150 a year**, each app sells several price points at once for the same thing, and the cheapest yearly price is usually an offer you only see in some flows. That last point is exactly what reviewers complain about.

## What reviewers said about price and billing

From `feedback.md` (307 reviews, 3 sources, collected 2026-11-10). These are research, never testimonials.

| theme | reviews | sources | what it is really about |
| --- | --- | --- | --- |
| Price and paywalls | 63 | 3 | too dear for a piano app; the price charged doesn't match the store page |
| Paywall after a few notes or lessons | 44 | 1 (thin) | the price shows up after onboarding, sometimes mid-lesson |
| Billing, cancelling and refunds | 31 | 3 | trial converted to the dearest (yearly) plan; can't find cancel; refunds refused |
| Ads | 3 of 13 | 2 | ads or cross-promotion inside a paid app |

Read with care: 35 reviews involve a child, and much of the price anger is kids who want it free. The billing complaints (31, three sources, average 1.4 stars) are from paying adults, and they are the ones to fix.

## The model

- **Free:** the whole first course, *Getting started*, through to a finished song (fix 1). No time limit, no account needed to start, no paywall inside a lesson, ever. The paywall appears only on a locked course or song, or when the learner taps Plans.
- **Trial:** 7 days, the same on monthly and yearly, one per Apple ID (Apple's introductory-offer rule). Push reminder 2 days before it converts (fix 2, `/replica-backend` reminder job).
- **Flat, not per seat.** Solo is one learner. Household is up to 5 learners on one account (the `max_profiles` trigger in `schema.sql` already enforces this). No surprise jumps: the only way to pay more is to choose Household yourself.
- **Monthly and yearly, yearly = 10 months.** $99.99 vs 12 × $9.99 = $119.88, so yearly saves 2 months. **Monthly is the default selection**, because the complaint is a trial that converted to yearly without people noticing.
- **One price everywhere.** No "20% off" second price for the same plan, no win-back offers at launch. The price on the landing page, the store page and the paywall is the same number.

### The tiers

| tier | for | monthly | yearly | learners | trial |
| --- | --- | --- | --- | --- | --- |
| Free | anyone starting out | $0 | $0 | 1 | n/a |
| **Solo** | an adult learning on their own | **$9.99** | **$99.99** | 1 | 7 days |
| **Household** | a family or two people sharing one piano | **$14.99** | **$149.99** | up to 5 | 7 days |

Why these numbers: about half the category's monthly price and about 20-30% under its yearly price. Price is the weakest moat (`fixes.md`: anyone can cut theirs), so it isn't the headline, but a newcomer with no ratings needs a reason to be tried, and "a fair price, said plainly" is the reason the reviews ask for. Raise later for new subscribers only; Apple keeps existing ones on their price unless you opt in.

Euro price points (App Store Connect sets them per storefront; choose these by hand for the EU): €9.99 / €99.99 Solo, €14.99 / €149.99 Household. Prices in the EU include VAT.

The schema also knows a Duo plan (2 profiles). It isn't offered at launch: two plans are easier to understand than three, and Household covers two people.

## Billing fixes, in the product

| complaint | fix | where |
| --- | --- | --- |
| price appears after the questions | price and trial terms on the second screen, before any question (brand string 4) | `/replica-build`, S01-S02 |
| trial converted to yearly | monthly preselected; the plan card says the charge date and amount ("Then $9.99 on Nov 26") | S05 |
| can't find cancel | Settings › Subscription opens `showManageSubscriptions` in one tap; the same link in every reminder | `/replica-build`, Settings |
| surprise renewal | push 2 days before a trial ends (brand string 14); App Store renewal emails stay on | `/replica-backend` |
| refunds refused | a "Request a refund" row in Settings that opens `beginRefundRequest` (StoreKit 2) | Settings |
| ads | none, for anyone | everywhere |
| deleting the account | "Delete account" in Settings, with a line that the subscription must be cancelled in Apple Settings (Apple doesn't allow it from the server) | Settings |

## Products to create in App Store Connect

This is an iOS app selling digital content, so it **must use in-app purchase, not Stripe** (`architecture.md`). You create these in App Store Connect › your app › Subscriptions. One subscription group, so a learner can switch between them and Apple prorates.

| subscription group | reference name | product id | duration | US price | intro offer | level in group |
| --- | --- | --- | --- | --- | --- | --- |
| Handspan | Household yearly | `app.handspan.household.yearly` | 1 year | $149.99 | free, 1 week | 1 (highest) |
| Handspan | Household monthly | `app.handspan.household.monthly` | 1 month | $14.99 | free, 1 week | 2 |
| Handspan | Solo yearly | `app.handspan.solo.yearly` | 1 year | $99.99 | free, 1 week | 3 |
| Handspan | Solo monthly | `app.handspan.solo.monthly` | 1 month | $9.99 | free, 1 week | 4 |

- The `app.handspan` prefix assumes the bundle id; change it if the name changes after the trademark search.
- `subscription-sync` maps `household.*` to `max_profiles = 5` and `solo.*` to 1.
- Turn on App Store Server Notifications v2 (production and sandbox URLs → `appstore-notifications`).
- Family Sharing: leave **off**. Household already covers families, and turning it on can't be undone for a product.

If you later sell on the web as well (a web player, or a teacher plan), that is when Stripe comes in. Not at launch.
