# Fixes and positioning

From `replica/reviews.csv` (307 reviews) ranked by `reviews.py` with `replica/themes.json` into `replica/feedback.md`. Date: 2026-11-10.

## The sample, honestly

| source | reviews | how | dates |
| --- | --- | --- | --- |
| App Store (US) | 250 | Apple's official customer-reviews RSS feed, 5 of its 10 pages (the other 5 came back empty on every retry) | 2026-08-12 to 2026-11-02 |
| Hacker News | 35 | official Algolia API, every comment matching "simply piano" | 2018 to 2025 |
| Trustpilot | 22 | read by hand: the hellosimply.com and www.simplypiano.com profiles (one Simply Draw review left out) | 2022 to 2026 |

- App Store ratings in the sample: 108 five-star, 29 four, 32 three, 22 two, 59 one. Most people who review it like it. This file is about the rest.
- **Many App Store reviewers are children.** 35 reviews (23 App Store, 8 HN, 4 Trustpilot) mention a kid, a parent or an age. Much of the price anger comes from kids who want it free, not from paying adults. Read the price numbers with that in mind.
- **Not collected:** Google Play (its terms forbid automated collection), Reddit (the page reader could not open it; read 10-20 threads by hand before launch), G2 and Capterra (the app isn't listed there).
- Apple's feed gives no link per review. Each App Store row links to the feed page it came from, with the review id after `#`.
- The "Ads" theme (13 hits) is mostly the word "advertising". Only 3 reviews complain about ads inside the app, so it isn't ranked below.

---

## 1. What they hate

| # | problem | reviews | sources | |
| --- | --- | --- | --- | --- |
| 1 | Price feels too high for a piano app, and prices shown don't match what's charged | 63 | 3 | |
| 2 | The paywall arrives a few notes or lessons in, often mid-lesson | 44 | 1 | thin: App Store only |
| 3 | Billing: charged during or right after a trial, can't find how to cancel, refunds refused | 31 | 3 | |
| 4 | Note recognition rejects correct notes (and sometimes accepts wrong ones) | 21 | 3 | |
| 5 | Too strict: whole sections restart after 3-5 mistakes, tempo drops, "zero stars" | 12 | 1 | thin: App Store only |
| 6 | Doesn't really teach: rhythm, theory, technique, playing on your own | 11 | 2 | |
| 7 | Pace and level: too basic for returning players, no way to skip ahead | 10 | 3 | |
| 8 | Too hard or too fast for beginners | 10 | 1 | thin: App Store only, mostly children |
| 9 | Support doesn't answer (or only an AI agent does) | 8 | 1 | thin: Trustpilot only |

Quotes, verbatim:

1. **Price**
   - "the cost for individual plan is not what the App Store says it is. It costs $230 per year (over the original $150)" — [App Store, 2★](https://itunes.apple.com/us/rss/customerreviews/page=10/id=1019442026/sortby=mostrecent/json#review-14427573594)
   - "I'd have paid a reasonable amount monthly - but that's not reasonable." — [Trustpilot, 2★](https://www.trustpilot.com/reviews/6988b96cca656da096b66d7e)
2. **Early paywall**
   - "Asked me to get premium access after first three notes THREE NOTES" — [App Store, 1★](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1019442026/sortby=mostrecent/json#review-14713330606)
   - "It's annoying that they make you set up everything before asking you to pay. Just tell me there's a subscription so we don't waste each other's time." — [App Store, 3★](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1019442026/sortby=mostrecent/json#review-14723646003)
3. **Billing**
   - "I thought when my free trail was over I would be charged 14.99 monthly, but got hit the yearly membership fee of $169.00!" — [App Store, 1★](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1019442026/sortby=mostrecent/json#review-14707710518)
   - "Charged me for both monthly and annual subscription plus songbook thing I didn’t sign up for - all even though I cancelled one day into a 7 day free trial." — [Trustpilot, 1★](https://www.trustpilot.com/reviews/695e3e27ebfb109aa366fd01)
4. **Recognition**
   - "You often need to play at max volume and it still gets it wrong all the time. Even a part played perfectly can be said to be wrong over and over again" — [App Store, 2★](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1019442026/sortby=mostrecent/json#review-14600308777)
   - "it counts as progress when bunch if random ... Notes are hit and one of those is the one that is on screen. ... So my daughter would trick the app to move forward like that" — [App Store, 4★](https://itunes.apple.com/us/rss/customerreviews/page=2/id=1019442026/sortby=mostrecent/json#review-14732184380)
5. **Too strict**
   - "it forces you to play perfectly and starts you all over when you only make 3 mistakes" — [App Store, 1★](https://itunes.apple.com/us/rss/customerreviews/page=8/id=1019442026/sortby=mostrecent/json#review-14495139100)
   - "IM 9YRS OLD AND IT GAVE ME ZERO STARS. IT MADE ME DISAPPOINTED IN MYSELF." — [App Store, 1★](https://itunes.apple.com/us/rss/customerreviews/page=9/id=1019442026/sortby=mostrecent/json#review-14463364920)
6. **Teaching depth**
   - "It listens to what notes you play, but it can’t fix your posture, dynamics, technique, hand shape, pedaling, etc. It barely even teaches any theory" — [App Store, 1★](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1019442026/sortby=mostrecent/json#review-14612752429)
   - "it focuses too much on simple songs or techniques" — [Hacker News](https://news.ycombinator.com/item?id=34400008)
7. **Pace and level**
   - "Makes me learn from the very beginning when I already know how to read notes. ... Why bother asking skill level in the hundred questions survey at the beginning if you still have to start like you are brand new to Piano?" — [App Store, 1★](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1019442026/sortby=mostrecent/json#review-14612364023)

## 2. What is missing

| # | feature asked for by name | reviews | sources | |
| --- | --- | --- | --- | --- |
| 1 | Drill just the hard part of a song (loop a bar, skip to a section) | 3 | 2 | thin |
| 2 | A placement test, or a way to test out of lessons you already know | 3 | 1 | thin |
| 3 | Better keyboard connection: MIDI as the default for accuracy, lit-key keyboards | 14 mention MIDI | 2 | mostly HN advice to use MIDI |
| 4 | More and newer songs, and custom songs from your own MIDI files | 4 | 2 | thin |
| 5 | Left-handed and other access needs | 3 | 2 | thin |

- "sometimes I wish I could spend more time on the parts of a song that I find harder, rather than starting from the beginning each time." — [Hacker News](https://news.ycombinator.com/item?id=35748980)
- "Please add test skips" — [App Store, 5★](https://itunes.apple.com/us/rss/customerreviews/page=9/id=1019442026/sortby=mostrecent/json#review-14467069287)
- "I have to use the midi connect or else when I play a high C the app will always say it’s wrong." — [App Store, 4★](https://itunes.apple.com/us/rss/customerreviews/page=5/id=1019442026/sortby=mostrecent/json#review-14599770541)
- "I want something that let's me define a custom lesson plan based on MIDI files of songs he loves" — [Hacker News](https://news.ycombinator.com/item?id=30201464)

Not in the sample: **no review asked for an on-screen keyboard or learning without a piano** (0 matches), though recon flagged it. Don't build it early on this evidence.

## 3. What is unsolved

1. **Adults who want to actually learn piano, not play a game.** HN and the longer App Store reviews come back to this again and again. People want to read, keep time and play on their own. They don't want to memorise songs by following a cursor. They also distrust a score that a cheap mic or a random note can fool. Evidence: teaching depth 11/2 sources, recognition 21/3, plus the [teacher's review](https://www.italianpiano.com/piano/review-of-simply-piano-app-for-learning-to-play-the-piano/) found during recon.
2. **People who want to pay fairly and know what they pay.** The anger isn't about having a price at all. It's about how it's sold: the price shows up after onboarding, yearly is the default, the trial converts to the dearest plan, and the charge doesn't match the store page. Evidence: price 63/3 sources, billing 31/3.
3. **Children learning alone.** About 1 in 9 reviews involve a child. The app's strictness and scores land hard on them: "made me cry", "zero stars", restarts after 3 mistakes. Evidence: 35 child mentions/3 sources, harsh restart 12 (thin).

---

## Fix plan

Ranked by evidence × how cheap it is to fix. Each fix is added to `features.csv` with `original` = `no`.

| # | fix | size | owner | evidence |
| --- | --- | --- | --- | --- |
| 1 | **Fair start.** The whole first course is free, through to a finished song; the paywall never interrupts a lesson. Price and trial terms come on the second screen, before any questions. | S | `/replica-build` (onboarding order), `/replica-launch` (copy) | early paywall 44; "set up everything before asking you to pay" |
| 2 | **Billing that can't surprise anyone.** One price everywhere, matching the store. A monthly plan with the same trial as yearly. A push reminder 2 days before a trial converts. "Manage subscription" in Settings (StoreKit `showManageSubscriptions`). No ads or cross-promotion for anyone. | S | `/replica-launch` (pricing), `/replica-backend` (reminder job) | billing 31/3 sources, price 63/3 |
| 3 | **Recognition you can trust, both ways.** Per-piano mic calibration in onboarding. Octave-correct detection tested on real pianos. A wrong note never counts, even when the right one is also in the chord. MIDI is offered first whenever a keyboard is plugged in. One tap to say "I played that right" (logged for tuning). | L | `/replica-build` (player), `/replica-test` (recorded-piano test set) | recognition 21/3 sources; random-notes false pass |
| 4 | **Kind mistakes.** Never restart a whole section: loop only the bar that went wrong, at the tempo it went wrong. Offer "practise this bar" in one tap. No zero-star screens: 0 stars reads "Almost. Try this bar slower?" (already in `components.md`, Result). Restart stays visible, never hidden. | M | `/replica-build` (player, S12-S14) | harsh restart 12 (thin); drill-the-hard-part 3/2 sources; "restart button is hidden" |
| 5 | **Placement and test-out.** A 2-minute placement after onboarding, and a "test out" on every course: play its final piece, and with 2 stars you skip the course. | M | `/replica-build` (S03, S09) | pace and level 10/3 sources; "test skips"; "hundred questions survey" |
| 6 | **Teach the why.** A separate timing score (early/late per note, not just right/wrong). A 30-second theory card before each new concept (rests, time signatures, key signatures early). A posture and fingering tip at the moments where they matter. | M | `/replica-build` (content), `/replica-design` (cards) | teaching depth 11/2 sources |

Not in the plan (too thin or out of scope for now): lit-key keyboard support (1 review), left-handed mode (1), cross-device login (1, and the architecture already syncs), custom MIDI-file lessons (1, a good later feature for teachers and parents).

Pricing and billing details (plan prices, trial length, family pricing) go to `/replica-launch`. The prices reviewers quote ($120 → $245 a year; $169 yearly after a trial; $350-$399 family) are their claims. Check the original's current public pricing page before using any of them.

---

## The angle

**A. Learn piano for real**
```
For adults who want to actually learn piano, not just follow falling notes,
[your app] hears every note correctly, lets you drill the bar you keep missing,
and teaches the rhythm and reading you need to play on your own.
Evidence: recognition 21 reviews / 3 sources; teaching depth 11 / 2; harsh restarts 12 / 1 (thin).
```

**B. Fair from the first note**
```
For beginners who are tired of paywalls after three notes and surprise renewals,
[your app] gives you a whole free course, one honest monthly price, and a reminder before you're ever charged.
Evidence: price 63 reviews / 3 sources; early paywall 44 / 1 (thin); billing 31 / 3.
```

**C. Kind to kids**
```
For parents whose kids get upset by zero-star scores and restart-from-the-top screens,
[your app] loops only the bar that went wrong and celebrates progress instead of perfection.
Evidence: 35 child mentions / 3 sources; harsh restarts 12 / 1 (thin).
```

**Recommendation: A, with B built in as table stakes.**
- **B is the strongest evidence but the weakest moat.** Any competitor can drop its price. Much of the price anger also comes from children who want it free, who aren't the people who pay. So fair billing ships in the MVP (fixes 1-2, both size S) and goes on the landing page, but it isn't the headline.
- **A is what paying adults complain about after they've paid**, in the longer and more thoughtful reviews. It builds on the architecture's biggest bet: on-device recognition, tested on real pianos. Fixes 3-6 are that product.
- **C is a strong second audience.** Fix 4 serves it for free. Make it the angle of a kids' profile later.

The original's name stays out of the app name, ads and store listing. A factual comparison page is a question for a lawyer in your country.

Next: `/replica-brand`, which uses angle A for the name and voice.
