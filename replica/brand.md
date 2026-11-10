# Brand

Angle (from `fixes.md`): **learn piano for real**, for adults who want to read, keep time and play on their own, with fair billing as table stakes. Date of every check below: 2026-11-10.

## Name

**Working name: Handspan.** Runner-up: **Evenhand.** Neither is cleared. The trademark searches are still to run, and the choice is yours.

Why Handspan: a hand span is the reach of your hand across the keys, a word every pianist uses. It is concrete and physical, it says "real playing" without saying "easy" or "fast", it is two plain English words, and it shares no sound, look or meaning with the original's name or with the other piano apps found (Flowkey, Skoove, Yousician, Pianote, Piano Marvel, Playground Sessions, Simpia, Pianora).

Its one real weakness: it is one letter from **handpan** (a steel drum). Searching "handspan" in both stores today returns handpan apps. An exact-name app normally ranks first for its own name, but expect some confused searches, and always pair the name with "piano" in the store subtitle.

### How 20 became 5

Round one, across styles. Checked on the US App Store (Apple's public search API) and by domain registry lookup (RDAP).

| candidate | style | outcome |
| --- | --- | --- |
| Truenote | descriptive | out: "TrueNote" voice-notes app, "True Note" record-player app |
| Barwise | compound | out: "BarWise" app exists |
| Sightline | descriptive | out: five apps with the name |
| Realkeys | descriptive | out: generic, says nothing |
| Barloop | compound | out: "BarLoop" app exists |
| Clefwork | compound | out: "Clefwork: Music Theory", same category |
| Handspan | metaphor | **finalist** |
| Keysmith | compound | out: a Mac keyboard-shortcut app has the name (from memory, not checked today) |
| Notebar | compound | not checked (the store search errored twice); generic |
| Klavio | invented | out: looks and sounds like Klaviyo, a large software brand |
| Etudo | invented | **finalist**, then rejected by the web check |
| Octava | invented | out: "Octava - Singing & Vocal Coach", same category |
| Sostenu | invented | out: can't be spelled after hearing it |
| Tactus | metaphor | out: "Tactus: Feel Music", same category |
| Fermata | metaphor | out: "Fermata: Music Theory Practice", same category |
| Ostinato | metaphor | **finalist**, then rejected by the web check |
| Legato | metaphor | out: "Legato: Music Practice Journal", same category |
| Downbeat | metaphor | out: DownBeat magazine and two metronome apps |
| Countin | verb | out: reads as "counting" |
| Rehearse | verb | out: five apps with the name |

Round two added Surehand, Handwise, Tenkeys, Barline, MiddleC, Tenuto, Ossia, Evenhand, Truekeys, Pianora, Clavera, Keystead, Wellkey, Steadyhand and Countbar, because round one left too few. Seven are existing apps (Surehand, Handwise, Tenuto, Pianora, Keystead, Steadyhand and "Middle C"), Truekeys collides with McAfee's "True Key", Barline and Ossia could not be checked (the store search errored), and Tenkeys, Wellkey and Countbar were weak. **Evenhand** and **Clavera** survived.

### The five finalists, checked

| check | Handspan | Evenhand | Clavera | Etudo | Ostinato |
| --- | --- | --- | --- | --- | --- |
| App Store, exact name (US; GB where the search answered) | none found; results are handpan apps | none found | none found | none found | none by exact name |
| Google Play, exact name | none found; handpan apps | none found | to run | to run | to run |
| The web, "name + app / music" | a Helsinki music artist on Bandcamp; otherwise the piano term | a 2002 film (owns evenhand.com), "Evenhand Publishing" (a music publisher in Tennessee), a workplace-learning app concept | "Clavera AI" (a software firm), "La Clavera" (a music artist) | **conflict: "etudo", a digital learning platform for music students (Austria)** | **conflict: "Ostinato Institute" (music education app) and "Ostinato: repeat with purpose" (practice app)** |
| .com | registered | registered | registered | registered | registered |
| .app | registered | registered | no record found | registered | registered |
| other domains with no record found | gethandspan.com, handspanpiano.com, handspanapp.com, handspan.io, handspan.music | evenhandpiano.com, evenhand.io, evenhand.music | getclavera.com, claverapiano.com, clavera.io, clavera.music | (not pursued) | (not pursued) |
| GitHub handle | `handspan` is taken | `evenhand` is taken | `clavera` is taken | taken | taken |
| X, Instagram, TikTok handles | to run | to run | to run | n/a | n/a |
| US trademark (tmsearch.uspto.gov, classes 9, 41, 42) | **to run** | **to run** | **to run** | n/a | n/a |
| EU trademark (euipo.europa.eu eSearch, or TMview) | **to run** | **to run** | **to run** | n/a | n/a |
| Canada (ised-isde.canada.ca) | to run | to run | to run | n/a | n/a |
| WIPO Global Brand Database | to run | to run | to run | n/a | n/a |
| verdict | **recommended** | runner-up | third | rejected | rejected |

Notes on the checks:
- "No record found" is a registry lookup that returned nothing. It usually means the domain is free; confirm at a registrar before you count on it.
- The trademark databases need a browser session, so none of those searches was run here. Search class 41 (education) as well as 9 and 42. Evenhand needs a careful look in class 41 because of the music publisher.
- These are screening checks, not legal clearance. Before spending money on the name, a trademark lawyer should do a proper search.

If the name changes, it lives in `brand.json` (`name`) and in two comment lines in `design/swift/`. Nothing else has to move.

## Palette

The original's public brand is violet (`#8217FF`) on cream (`#F3F0DF`) with dark violet text (`#200854`), set in a playful custom display font. Those colours, and three more violets from its site, are in `brand.json` so the sweep catches them.

Ours has one brand hue from a different family, a cerulean called **Tide**, with neutral ink and the blue-grey sky from your reference image. No violet, no cream.

| name | role in tokens | light | dark |
| --- | --- | --- | --- |
| Tide | `tint`, `note-target` | `#0b62a4` | `#6cc0f2` |
| Ink | `accent` (the one solid button) | `#0e0f12` | `#f2f5f8` |
| Sky | `sky-top` / `sky-mid` | `#557f97` → `#c7d8e6` | `#04080c` → `#10314d` |
| Brass | `warning`, stars | `#9a5700` | `#f0b04a` |
| Fern | `success`, `note-correct` | `#1b7443` | `#4cc38a` |
| Clay | `danger`, `note-wrong` | `#c2352a` | `#ff7a6e` |

What changed from the placeholder palette: the tint moved from indigo-blue (`#2f56d6`, `#93a7ff`) to Tide, and the dark theme's surfaces lost their indigo cast (`sky-mid` `#1b2552` → `#10314d`, plus bg, surface, border and paper). The light theme's neutrals and sky are unchanged.

Contrast after the change: 44 pairs, 0 below WCAG AA (`contrast.py`). `tokens.css` and `swift/Tokens.swift` are in step with `tokens.json`, and `preview.png` is re-rendered.

## Logo brief

- **Idea:** the span. One arc reaching from one key to another, the way a hand reaches an octave and the way a slur joins two notes on the page.
- **Mark type:** symbol plus wordmark. The symbol is an open arc over two short vertical strokes (two keys). The wordmark is "Handspan" in one word, sentence case.
- **Sizes:** the arc and two strokes must read at 16 px (favicon) with no detail lost, and fill a 1024 px app icon.
- **Colour:** white mark on the Sky gradient for the app icon; Ink on white and white on Ink for everything else. Tide is an accent, never the whole background.
- **Type:** an open-licensed sans such as Inter, Instrument Sans or Geist. Not SF Pro: Apple's licence does not allow it in a logo.
- **Deliverables:** SVG (symbol, wordmark, lockup); app icon 1024×1024 with no transparency for iOS, plus the iOS 26 layered icon source; favicon set; social image 1200×630.
- **Must not resemble the original's mark.** Theirs is a rounded lowercase wordmark with a four-point sparkle, in cream on violet. So: no sparkle or star, no violet, no cream, no bubbly lowercase lettering, no mascot. Put their logo and the logos of the other piano apps next to the drafts and check by eye.
- Also avoid a plain row of piano keys or a single music note on its own. Half the category uses them.

## Voice

Three words:
- **Plain**, not dumbed down. Everyday words, real musical terms explained once.
- **Patient**, not slow. A missed note is information. No pressure, no shame, no fake cheer.
- **Exact**, not cold. Say which bar, which note, which price, which date.

| do | don't |
| --- | --- |
| "Bar 6 is the tricky one. Loop it at 70%?" | "Oops! Try again!" |
| "That was F. Aim one key lower." | "Wrong note." |
| "{price} a month after your free course. We remind you 2 days before any charge." | "Start your free trial now!" with the price in small print |
| "46 of 48 notes on time." | "Amazing!!! You're a star!" |
| "A rest is a counted silence. Here it lasts one beat." | "Don't worry about the theory for now." |

House rules:
- Never promise speed or ease ("fast", "easy", "in minutes"). Don't use the word "simply" in any copy (`avoid_in_copy` in `brand.json`).
- Prices and dates are always written out in full, next to the button they belong to.
- Sentence case everywhere. No exclamation marks in errors or prices.
- British or American spelling: pick one at launch and hold it. The strings below use American ("practice" as a verb).

### The most-seen strings

Placeholders in braces come from the app. The price is set in `/replica-launch`.

| # | where | string |
| --- | --- | --- |
| 1 | Welcome (S01), headline | Learn piano for real. |
| 2 | Welcome, line under it | Handspan hears every note you play and shows you what to fix. |
| 3 | Welcome, button | Start the free course |
| 4 | Price screen, shown second | The first course is free, start to finish. After that it's {price} a month. We'll remind you 2 days before any charge. |
| 5 | Sign in (S06) | Enter your email. We'll send a 6-digit code. No password. |
| 6 | Mic prompt (S04) | Handspan listens to your piano to check each note. The sound stays on this {device}. |
| 7 | Home (S07), main button | Start lesson · Resume at bar {n} |
| 8 | Player hint (S11) | Play {note}, {hand} hand, finger {n} |
| 9 | Player, wrong note | That was {played}. Aim {interval} {direction}. |
| 10 | Result, passed (S14) | {hit} of {total} notes on time. |
| 11 | Result, not yet | Almost. Bar {n} is the tricky one. Loop it at {tempo}%? |
| 12 | Streak reset (S19) | New week, new streak. Ten minutes counts. |
| 13 | Offline | No connection. Your practice is saved on this {device} and will sync later. |
| 14 | Trial reminder (push) | Your free trial ends in 2 days. Keep it, or cancel in Settings › Subscription. |

String 6 is a promise: the build must keep audio on the device, including the "I played that right" report (fix 3), or the line has to change.

## Sweep

```
python3 sweep.py . --config replica/brand.json                  → Clean (exit 0)
python3 sweep.py replica/design --config replica/brand.json     → Clean (exit 0)
grep -riw "simply" replica/design                               → no matches
```

For comparison, the same sweep with `--include-replica` finds 170 hits, all in the planning files where the original's name belongs (`recon.md`, `reviews.csv`, `fixes.md`). They never ship.

There is no app code yet, so the sweep has little to check. Run it again after `/replica-build`, and check by eye: the app icon, the launch screen, the page titles, the email templates and the social image.

Next: `/replica-launch`.
