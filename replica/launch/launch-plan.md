# Launch plan

Reads `fixes.md` (angle A, fair billing as table stakes), `feedback.md` and `pricing.md`. Date: 2026-11-19. Nothing here is posted or sent yet; every outward step waits for your go.

## Before launch: what must be true

| # | item | owner | done when |
| --- | --- | --- | --- |
| 1 | Trademark searches for Handspan (US classes 9, 41, 42; EUIPO; WIPO) | you | `brand.md` table filled in, no conflict |
| 2 | Domain bought (first choice from `brand.md`: gethandspan.com or handspanpiano.com; handspan.com and handspan.app are taken) | you | DNS points at the host |
| 3 | Landing page live with a working waitlist (`site/index.html`, set `data-endpoint`) | `/replica-deploy` | a test signup lands in the list |
| 4 | Privacy policy, terms, support email at the URLs in the footer and `listing.json` | you + `/replica-deploy` | the three URLs answer |
| 5 | TelemetryDeck and Sentry live in the TestFlight build | `/replica-backend` | one test event and one test error visible |
| 6 | Real screenshots replace `preview.png` (hero and store) | `/replica-build` | taken from the build, not the design file |
| 7 | App Store Connect: 4 subscription products (`pricing.md`), privacy label ("Data not collected" for audio; email, purchases, usage for analytics), age rating, review notes with a demo account | you | submitted |

Review notes for Apple (Guideline 4.1, Copycats): say in the first lines what is different. On-device recognition with per-piano calibration, bar looping instead of restarts, separate timing score, placement and test-out, the whole first course free. Show the same in screenshots 1 to 3.

## Waitlist and beta (weeks 1-4 before launch)

- **Waitlist:** the landing page form. One email at signup ("You're on the list. We'll write once, when it's ready."), one at launch. Nothing in between unless they opt into the beta.
- **TestFlight beta:** the first 50 from the waitlist who say they have a real piano. Ask three things after a week: did it hear you right (and on which piano), did the bar loop help, would you pay $9.99 a month. Log every "I played that right" tap: it's the recognition test set.
- **Beta quotes:** only with written permission, first name and instrument, never edited. Until then the page has no proof section.

## Where the unhappy users of the category talk

Research, not targets for spam. Read first, answer real questions, and say you're the maker every time.

| place | why | what to post |
| --- | --- | --- |
| r/piano (beginner threads, "which app" questions) | adults who want to read and keep time, the angle's audience | answer questions; link only when someone asks for an app that doesn't restart or that works with MIDI |
| r/pianolearning | self-taught adults | a build-in-public post on how on-device recognition is tested on real pianos |
| Hacker News | 35 of the research comments came from HN; they recommend MIDI and distrust mic scoring | Show HN (below) |
| Piano World forum (Adult Beginners) | older adult learners, long threads about apps | one post asking for beta testers with acoustic pianos |

`fixes.md` says Reddit wasn't collected (the reader couldn't open it). Read 10-20 threads by hand before the first post and add what you find to `feedback.md`.

## Launch posts

**Show HN** (leads with the fix, not the clone):

> Show HN: Handspan, a piano tutor that loops the bar you missed instead of restarting the song
>
> I wanted to learn to read and keep time, not follow falling notes. Handspan listens on the device (YIN pitch detection, calibrated to your piano in 30 seconds; MIDI if you have it), gives a separate timing score per note, and when you miss something it loops that bar at your tempo. The first course is free to the end; after that it's $9.99 a month, with a reminder 2 days before any trial charge. No audio leaves the phone. I'd like to hear from people with acoustic pianos where recognition goes wrong.

**Product Hunt:** tagline "Learn piano for real, on your own piano" (39 chars). First comment: the same three fixes, the price, and a request for feedback from acoustic-piano players. Launch on a Tuesday to Thursday, 12:01 AM Pacific.

No ads at launch. If you add them later, the original's name never goes in ads or keywords (`brand.json` `avoid`).

## The first 10 users, by hand

1. 3 adults returning to piano after years away (they hit "too basic, can't skip": test placement and test-out).
2. 3 adult beginners with an acoustic piano (the hardest case for recognition).
3. 2 with a MIDI keyboard (the accuracy baseline).
4. 1 parent of a child aged 8-12 (fix 4, kind mistakes, and the Household plan).
5. 1 piano teacher (does the theory card say it right).

Find them through the beta list and the forums above. A 20-minute call each, watching them play their first lesson. Write what you see in `replica/feedback-beta.md`, with their permission.

## Numbers to watch in the first 30 days

- First course finished (the free part): the promise on the landing page.
- "I played that right" taps per 100 notes, split by mic and MIDI: the recognition promise.
- Trial → paid, and cancels in the 2 days after the reminder: if many cancel there, the reminder is working as intended. Don't remove it.
- Refund requests: target close to zero, because nobody should be surprised.

Next: `/replica-deploy`.
