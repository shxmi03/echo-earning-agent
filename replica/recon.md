# Recon map: Simply Piano (iOS, iPhone + iPad)

Scope: the core learning loop. Onboarding with a level choice, a linear course path made of lessons and exercises, live note recognition (microphone or MIDI) with feedback, a song library with practice controls, and a subscription with a free tier. Not in scope: the sister apps (Guitar, Sing, Draw), XR, workshops, Trinity certificates.
For: a paid product to sell (proposed default, not yet confirmed by the user)
Date: 2026-11-03

> Every screen and flow below is inferred from public sources. Nobody logged into the app for this map. Rows that rest on one source are marked (1 src).

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | App Store listing (HR) | https://apps.apple.com/hr/app/simply-piano-learn-piano-fast/id1019442026 | pitch, IAP prices in EUR, 4.7 from 1.9k ratings, privacy labels (audio data), iOS 15+, 14 languages |
| 2 | Help center: Simply Piano collection | https://piano-help.hellosimply.com/en/collections/3968889-simply-piano | 92 articles: the full feature surface |
| 3 | Help: Learning basics | https://piano-help.hellosimply.com/en/articles/7943490-learning-with-simply-piano-the-basics | feedback colours: grey = heard, yellow = correct key after a mistake |
| 4 | Help: Understanding PLAY | https://piano-help.hellosimply.com/en/articles/7943680-understanding-play | sheet music library, Listen / Teach Me / Play / Feedback / Auto Scroll / My Library, unlock rule |
| 5 | Help: Star levels | https://piano-help.hellosimply.com/en/articles/7943591-understanding-star-levels | up to 3 stars per song, gate fraction "0/6" |
| 6 | Help: Song Library menu | https://piano-help.hellosimply.com/en/articles/16945914-simply-piano-song-library-menu-navigation | scrub, pause menu, speed, hands, practice (wait) mode, metronome, finger numbers |
| 7 | Help: Courses menu | https://piano-help.hellosimply.com/en/articles/16945681-simply-piano-courses-menu-items | pause menu in courses: Play, Restart, Listen, Exit to the "mini-journey" |
| 8 | Help: Free access | https://piano-help.hellosimply.com/en/articles/11056528-what-can-i-access-for-free-in-simply-piano | free: Piano Basics + Touch Intro; trial only on the yearly plan, one per Apple ID |
| 9 | Help: 5-minute workouts | https://piano-help.hellosimply.com/en/articles/7939170-what-are-5-minute-workouts | weekly; flash cards, song training, on-the-go; being replaced |
| 10 | Help: Streaks | https://piano-help.hellosimply.com/en/articles/15496066-how-do-streaks-work-in-simply-piano | weekly streak, 2 freezes, +1 every 5 weeks, reminder emails |
| 11 | Help: Family profiles | https://piano-help.hellosimply.com/en/articles/2749747-learn-with-your-family-multiple-profiles | up to 5 profiles, email + 4-digit code login, Duo plan on iOS |
| 12 | Help: Kids XP | https://piano-help.hellosimply.com/en/articles/15913867-how-do-xp-and-rewards-work-kids-profiles | kids 4-10: XP, levels, unlockable rewards (iOS only) |
| 13 | Help: Challenges | https://piano-help.hellosimply.com/en/articles/12175788-simply-piano-challenges | timed song events, weekly drops, stars, badges, certificates |
| 14 | Review: Indie Musician Resources (2020, updated 2021) | https://indiemusicianresources.com/simply-piano-review/ | onboarding questions, 2 paths (Soloist / Chords), ~12 lessons per course, sheet music, US prices back then |
| 15 | Review: Italian Piano (teacher) | https://www.italianpiano.com/piano/review-of-simply-piano-app-for-learning-to-play-the-piano/ | weak points of recognition: octave errors, wrong notes pass, playing loud and staccato |
| 16 | Pianist Magazine | https://www.pianistmagazine.com/blogs/simply-piano-a-piano-learning-app-for-beginner-pianists-and-above/ | feedback on tempo, accuracy, rhythm; USB MIDI |
| 17 | Marketing site | https://www.hellosimply.com/ | "designed by educators and enhanced by AI" |
| 18 | Google Play listing | https://play.google.com/store/apps/details?id=com.joytunes.simplypiano | 4.6 from ~995k ratings, "5-min practice per day" |

Not used yet: the user's own account (none given), public walkthrough videos (only titles seen), the Terms of Use (https://www.hellosimply.com/legal/terms). Read the terms before using a personal account for recon.

## Core loop

Put the phone on the music stand, play the highlighted notes on a real piano, and the app hears them and tells you right away if you got them right, step by step, until you can play a song you know.

## Screens

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Welcome | first launch | start onboarding or log in | hero, primary CTA, "I have an account" | default |
| S02 | Instrument question | onboarding step | acoustic piano, keyboard, or no piano (switches to Touch path) | option cards | selected, unselected |
| S03 | Experience and goal | onboarding steps | beginner / some / advanced; what you want to play | option cards, progress dots | selected |
| S04 | Mic permission and sound check | onboarding | request mic, confirm it hears a note | permission prompt, listening meter | granted, denied, no sound heard (guess) |
| S05 | Paywall | after onboarding, and on locked items | trial and plans (yearly with 7-day trial, monthly, Duo, Family) | plan cards, default plan, CTA, restore | trial available, trial already used |
| S06 | Account and profile create | after the paywall | email sign-in with a 4-digit code, profile name, adult / kid | email field, code input, profile type | code sent, wrong code, expired (1 src) |
| S07 | Home: course map | main screen | horizontal row of courses, progress per course, path choice | course cards, progress ring, lock badge, menu ☰, streak 🔥 | locked, in progress, done |
| S08 | Path choice | after Essentials I | Soloist or Chords path | two path cards | chosen (14) |
| S09 | Course "mini-journey" | tap a course | list of lessons, songs and star levels in order | lesson nodes, star-level gate "0/6", song nodes | locked, current, done, 1-3 stars |
| S10 | Lesson intro / video | tap a concept lesson | explain a new concept (note, chord, rhythm) | text, short video or animation, continue | default |
| S11 | Exercise player: static | inside a lesson | read a note and play it, no time pressure | staff with notes, on-screen keyboard strip, finger numbers, feedback colours | waiting, correct, wrong (yellow hint), not heard |
| S12 | Exercise player: moving stage | end of a lesson and in songs | play in time with a backing track, cursor scrolls | scrolling staff, cursor, backing audio, score meter, pause | playing, paused, fell back a few bars on too many mistakes |
| S13 | Pause menu | pause (top left) in S11/S12 | Play, Restart, Listen, Exit; in songs also speed, hands, practice mode, metronome, finger numbers | icon buttons, toggles, tempo slider | course variant, song variant |
| S14 | Result | end of a stage or song | stars, accuracy, timing; retry or continue | stars 0-3, score bars, CTAs | pass, fail, new best |
| S15 | Song library | Menu > Songs | browse songs by level and genre, section picker | search, filters, song cards, level tags, lock / "not ready yet" warning | free locked, premium, warning |
| S16 | Song detail | tap a song | choose a section (intro, verse, chorus) or the whole song | section list, stars per section, XP (kids) | locked, done |
| S17 | PLAY: sheet music | Menu > PLAY, unlocked at 80% of Essentials III | interactive sheet music with Listen, Teach Me, Play, Feedback, Auto Scroll | sheet view, blue cursor, scroll speed bar, heart (My Library) | locked, unlocked, favourited |
| S18 | Practice / 5-min workout | Menu > 5-Min Workout | short weekly session: flash cards, song training, on-the-go stages | three option cards | locked until Piano Basics lesson 2 |
| S19 | Streak | tap 🔥 | weekly streak count, freezes left | flame, counter, freeze icons | active, frozen, reset |
| S20 | Challenges | event banner | timed song challenge, weekly song drops, badges | event card, song list, badge screen, certificate | eligible, not eligible, ended |
| S21 | Kids XP and rewards | XP bar on the Songs screen (kids profiles) | level, XP, unlocked rewards (Tempo Rush, Song Mix) | XP bar, level badge, reward cards, celebration screen | locked reward, unlocked, needs more skills |
| S22 | Switch profiles | Menu > Switch Profiles | pick or add one of up to 5 profiles | avatar grid, add profile | 1 profile, full (5) |
| S23 | Settings | Menu > Settings | account, MIDI or mic input, reminders, language, white background, delete account | list rows, toggles | default |
| S24 | Input setup: MIDI | Settings, or a prompt when a MIDI device is plugged in | USB or Bluetooth MIDI keyboard instead of the mic | device list, test note | connected, not found |
| S25 | Touch keyboard player | Touch Intro course, no-piano path | play on an on-screen keyboard | full-width touch keys, staff | default |
| S26 | Help and support | Menu > Help & Support | in-app chat and FAQ | chat thread | default |

## Flows

```
F01 New user plays the first notes (activation)
    S01 -> S02 -> S03 -> S04 -> S05 (skip or start trial) -> S06 -> S07 -> S09 -> S10 -> S11
    happy path clicks: about 10 to 12 (inferred, not counted in the app)
    edge: mic denied, no piano (goes to the Touch path S25), noisy room, trial already used on this Apple ID
```

```
F02 Learner finishes a lesson (the core loop)
    S07 -> S09 -> S10 -> S11 (repeat 8 to 12 exercises) -> S12 -> S14 -> S09
    happy path clicks: 3 to reach the first exercise, then playing, not tapping
    edge: wrong note (yellow hint), note not heard, wrong octave accepted (15), too many mistakes in a moving stage (falls back a few bars), pausing mid-stage, app killed mid-lesson
```

```
F03 Learner practises a song from the library
    S07 -> S15 -> S16 -> S12 -> S13 (slow down, one hand, practice mode) -> S12 -> S14
    happy path clicks: 4
    edge: song locked (no subscription), "not ready yet" warning, scrubbing back to repeat a part
```

```
F04 Learner passes a star-level gate
    S09 star level "0/6" -> S16 -> S12 -> S14 (stars) -> repeat until the gate is met -> next lesson unlocks
    edge: stars spread over several songs count toward one gate
```

```
F05 Free user subscribes
    a locked course or song -> S05 -> pick a plan -> Apple payment sheet -> S07 unlocked
    edge: monthly plan has no trial, payment fails, restore purchases on a new device, already had a trial
```

```
F06 Family adds a profile
    S07 menu -> S22 -> add profile (adult or kid) -> S07 for that profile
    edge: plan does not cover more profiles, another family member logs in on their own device with the email + code
```

```
F07 Keeping the weekly habit
    any completed practice session -> streak +1 for that week -> S19
    edge: missed week uses a freeze automatically, no freezes left resets the streak, reminder email or push
```

```
F08 Connect a MIDI keyboard
    plug in USB or Bluetooth MIDI -> S24 -> test note -> back to S11 with MIDI input
    edge: Bluetooth headphones add audio lag (help article), device disconnects mid-stage
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Button | primary, secondary, ghost, icon | default, pressed, disabled, loading | all |
| Option card | single choice, with icon | selected, unselected | S02, S03, S08, S18 |
| Plan card | yearly with trial, monthly, duo, family | selected, recommended badge | S05 |
| Course card | free, premium | locked, in progress, done, progress ring | S07 |
| Journey node | lesson, song, star level, video | locked, current, done, stars 0-3 | S09 |
| Staff / notation view | static, scrolling (moving stage), sheet page | waiting, correct, wrong, hint | S11, S12, S17 |
| Keyboard strip | hint (bottom of player), full touch keyboard | idle, heard (grey), target (yellow), pressed | S11, S12, S25 |
| Cursor | moving stage, blue sheet cursor | playing, paused | S12, S17 |
| Pause menu | course, song | open, closed | S13 |
| Toggle and slider | tempo, hands, practice mode, metronome, finger numbers | on, off | S13, S17 |
| Score / stars | 0-3 stars, accuracy and timing bars | pass, fail, best | S14, S16 |
| Song card | free, premium, kids XP tag | locked, warning, done | S15, S20 |
| Streak flame | count, freeze icons | active, frozen, reset | S07, S19 |
| Badge / celebration screen | badge, level up, reward unlock | shown once per milestone | S20, S21 |
| Profile avatar | adult, kid, add | selected | S22 |
| Code input | 4 digits | empty, filled, error | S06 |
| Listening meter | mic level | silent, hearing, too loud | S04 |
| Toast / banner | event, error, offline | shown, dismissed | all |

## Inferred data model

```
Account       id, email, created_at, plan_id, trial_used (bool), locale
              evidence: S06, help "Log in", "4-digit sign-in code", "free trial" (8)
              confidence: high

Profile       id, account_id, name, type (adult | kid), avatar, input_mode (mic | midi | touch),
              path (soloist | chords | null), created_at
              evidence: S22, help "Family profiles" (11), "Kids XP" (12), S08
              confidence: high

Subscription  id, account_id, store (apple | google | web | gift | reseller), product_id,
              plan (individual | duo | family), period (month | year | 3 months | 6 months),
              status (trial | active | grace | expired | cancelled), renews_at, max_profiles
              evidence: S05, App Store IAP list (1), help billing articles (2)
              confidence: high

Course        id, title, path (foundation | soloist | chords | lead_sheet | touch | optional),
              order, free (bool), unlock_rule
              evidence: S07, review (14), help "Free access" (8)
              confidence: high

Lesson        id, course_id, order, kind (concept | song | star_level | video), title,
              stars_required (for star levels)
              evidence: S09, help "Star levels" (5), review (14)
              confidence: medium

Exercise      id, lesson_id, order, kind (static | moving), notation (MusicXML-like or note list),
              tempo, hands (left | right | both), backing_track_id
              evidence: S11, S12, review (14)
              confidence: medium

Song          id, title, artist, level (essentials | intermediate | pre_advanced), genre,
              sections[], license_id, premium (bool), xp_value
              evidence: S15, S16, S17, help "PLAY" (4), "Kids XP" (12)
              confidence: high

Attempt       id, profile_id, exercise_id or song_section_id, started_at, finished_at,
              accuracy, timing, stars (0-3), input_mode, tempo_pct, hands, practice_mode (bool)
              evidence: S14, review (14, 16)
              confidence: medium

Progress      profile_id, lesson_id, status (locked | open | done), best_stars
              evidence: S07, S09, help "Recover lost progress" (2)
              confidence: high

Streak        profile_id, week_start, current_weeks, freezes_left, last_session_at
              evidence: help "Streaks" (10)
              confidence: high

XpLedger      profile_id, source (lesson | song), amount, level, rewards_unlocked[]
              evidence: help "Kids XP" (12)
              confidence: high

Challenge     id, title, starts_at, joins_until, ends_at, eligibility_rule, song_ids[],
              badges[], kid_only (bool)
              evidence: help "Challenges" (13)
              confidence: medium

Favourite     profile_id, song_id
              evidence: PLAY "My Library" (4)
              confidence: high

Reminder      profile_id, days[], time
              evidence: help "Can I schedule practice reminders?" (title only, 2)
              confidence: guess
```

Relationships: Account 1-n Profile, Account 1-1 Subscription, Course 1-n Lesson, Lesson 1-n Exercise, Song 1-n Section, Profile 1-n Attempt, Profile 1-n Progress, Profile 1-1 Streak, Profile 1-n Favourite, Challenge n-n Song.

## Feature matrix

See `features.csv`. Must: 17, should: 15, could: 9, skip: 6.

## Out of scope (cannot or should not be cloned)

- **The song catalogue.** Imagine, All Of Me, Bohemian Rhapsody and the rest are licensed (composition and, for backing tracks, the recordings). The clone needs its own catalogue: public domain classical (Bach, Satie, Joplin), traditional songs, original pieces, or new licences you sign yourself.
- **Their curriculum, exercise content and arrangements.** The method (short exercises, then a song with a backing track, then star gates) can be rebuilt. Their lesson texts, videos, arrangements and course names cannot. Write your own.
- **Their note recognition engine.** Build it fresh or use a licensed or open-source pitch detection library.
- **The family of apps** (Guitar, Sing, Draw) bundled into the Family plan.
- **Partner deals**: Trinity College London certificates, Sweetwater reseller codes, ESA funds.
- **Simply Piano XR** and workshops.
- **Their brand**: name, logo, purple palette, mascot, copy.

## Size

Screens 26, flows 8, entities 14.

Hard parts:
1. **Real-time note recognition from the microphone**, including chords, octaves and a noisy room. It is the product. The top public complaint is that it gets octaves wrong and lets wrong notes pass (15). MIDI input is easy; the mic is not.
2. **Content production.** A real course path (two paths, ~28 courses of ~12 lessons each) plus a song library you have the rights to. This takes more work than the code.
3. **Notation and audio sync.** A scrolling staff in time with backing audio, with low latency, tempo changes and Bluetooth audio lag.

Also: Apple in-app subscriptions with trials, Duo and Family plans; streaks and reminders across devices; separate kid profiles (privacy rules for under-13s).

Size: **L** (a quarter) for an MVP. That covers onboarding, one free course, a MIDI-and-mic player for single notes, about 20 public-domain songs, stars, streaks and one subscription. Full parity, with chord recognition and a 28-course curriculum, is **XL**: rescope it.
