# Landing page

Built at `replica/launch/site/index.html` (one static file; `site/tokens.css` and `site/preview.png` are copies from `replica/design/`, so the folder deploys on its own). Angle A from `fixes.md`, with fair billing (B) as table stakes. Voice from `brand.md`: plain, patient, exact. No "easy", "fast" or "simply"; no exclamation marks. Date: 2026-11-19.

**No proof section.** There are no users yet, so there are no testimonials, user counts, ratings or press logos. Add real beta quotes later, with permission.

## 1. Hero

- Headline: **Learn piano for real.**
- Line under it: Handspan hears every note you play on your own piano, shows you what to fix, and teaches the reading and rhythm you need to play on your own.
- Button: **Join the waitlist** (before launch) → **Download on the App Store** (after).
- Under the button, small: The first course is free, start to finish. iPhone and iPad.
- Image: `design/preview.png` for now (Home and Player). **Replace it with a real screenshot from the build before launch.** The page says nothing the screenshot doesn't show.

## 2. The problem

Heading: **Most piano apps teach you to follow, not to play.**

- **They hear you wrong.** A right note marked wrong, a random handful of notes counted right. After a while you stop trusting the score, and then you stop practicing.
- **They make you start over.** A few mistakes and it's back to the top of the section, at a slower tempo, with no way to work on the one bar you keep missing.
- **And the price comes last.** You answer the questions, set everything up, and only then find out what it costs, or what the trial turns into.

(Paraphrased from the top themes in `feedback.md`: recognition 21 reviews / 3 sources, harsh restarts 12 / 1, early paywall 44 / 1, billing 31 / 3. No reviewer is quoted.)

## 3. How it works

1. **Put your phone on the music stand.** Any acoustic or digital piano. Handspan tunes itself to your piano in about 30 seconds. With a USB or Bluetooth MIDI keyboard, it reads the keys directly.
2. **Play the lesson.** Notes move toward a fixed line. Each one turns green when it's right and on time, and the hint says which note, which hand and which finger.
3. **Fix the bar, not the song.** Miss something and Handspan loops just that bar at a tempo you choose, then puts it back into the piece.

## 4. Features (fixes first)

| heading | line | fix |
| --- | --- | --- |
| Recognition you can trust | Tuned to your piano, octave-correct, and a wrong note never counts, even inside a chord. If it gets one wrong, tap "I played that right" and it learns. | 3 |
| Loop the bar you keep missing | No restart from the top. Handspan loops the bar that went wrong, at the tempo it went wrong, until it's yours. | 4 |
| Timing, not only notes | A separate timing score shows each note as early, on time or late. Rhythm is half of reading music. | 6 |
| The why, in 30 seconds | A short card before each new idea: rests, time signatures, key signatures. Real terms, explained once. | 6 |
| Start where you are | A 2-minute placement when you begin, and a test-out on every course. Play its final piece with 2 stars and move on. | 5 |
| Your sound stays on your phone | Note detection runs on the device. No recording leaves it. | brand string 6 |
| A fair start | The whole first course is free. The price is on the second screen, before any question. | 1 |

Below the table, smaller: **Also:** a weekly streak with freezes, songs in three levels, practice at any tempo, left or right hand alone, a metronome, up to 5 learners on Household. (Parity features: the price of entry, not the pitch.)

## 5. Pricing

Heading: **One price, said up front.**

| | Free | Solo | Household |
| --- | --- | --- | --- |
| for | starting out | one learner | up to 5 learners |
| price | $0 | $9.99 a month, or $99.99 a year | $14.99 a month, or $149.99 a year |
| | the whole first course, to a finished song | every course and song | every course and song, one profile each |

Under the table: 7-day free trial on monthly and yearly. We remind you 2 days before any charge. Cancel in one tap from Settings › Subscription. No ads, for anyone.

## 6. FAQ

- **Do I need a real piano?** Yes, for now. Any acoustic piano or digital keyboard with at least 61 keys. A MIDI cable or Bluetooth MIDI is the most accurate, but the microphone works on its own.
- **I already read a little. Do I have to start from middle C?** No. Take the 2-minute placement, or test out of any course by playing its final piece.
- **Is it for kids?** It's made for adults first. Kids do well with it too, because a mistake never sends them back to the start and there are no zero-star screens. Household gives each child their own profile.
- **What happens to my playing?** It's analysed on your phone and never uploaded. We store your results (which lesson, how many notes on time) so they sync across your devices.
- **What does the trial turn into?** The plan you picked, at the price shown next to the button, on the date shown next to the button. Monthly is selected unless you choose yearly. We send a reminder 2 days before.
- **How do I cancel?** Settings › Subscription in the app, one tap. Or in your iPhone's Settings › Apple ID › Subscriptions.
- **Android? Mac?** iPhone and iPad first. Join the waitlist and tell us what you use.

(No importer was built, so there is no "can I import from other apps" question.)

## 7. Final call to action

- Heading: **Ten minutes a day, on your own piano.**
- Line: Start the free course. You'll know within a week if it's for you.
- Button: **Join the waitlist**

Footer: Privacy · Terms · Support (the three URLs App Review needs) · © 2026 Handspan (working name).

## Checks

- Contrast: `contrast.py replica/design/tokens.json` → 44 pairs, 0 failing AA. One addition outside the tokens: in light mode the hero and final bands use a darker band of the Sky hue (`#34576b` → `#4a7187`), because the token sky fades to the page colour and white text on it failed. White text on it: 7.7:1 to 5.2:1. The buttons on those bands are white with ink text.
- Layout: rendered at 390 px and 1280 px, light and dark, no horizontal scroll.
- Voice: `grep -iwE "simply|easy|easily|fast|in minutes|!" replica/launch/site/index.html` → no matches in visible copy.
- Sweep: `sweep.py replica/launch/site --config replica/brand.json` → Clean. (On all of `replica/launch` it finds the `avoid` list inside `listing.json` and one research URL in `pricing.md`; neither ships.)
- Store listing: `listing.py replica/launch/listing.json` → 0 errors, 0 warnings.
