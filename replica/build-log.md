# Build log

The iOS app lives in `replica/app/` (see its README). Built from `recon.md`, `architecture.md`, `design/` and `brand.md`. Every string, lesson and line of code is written fresh.

**Builds and tests run on GitHub's `macos-26` runner** (Xcode 26.6), through `.github/workflows/ios.yml`. The container has no Swift toolchain and the local Mac is Intel. The first green build was on 2026-11-19 after three small compile fixes. It has not yet run on a device or a real piano, and screenshots for `/replica-diff` (`replica/clone-screens/`) are still to take.

| screen | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| shell | 2026-11-19 | done | a tab bar (only one main screen so far) | Xcode project written by hand: folder-synced groups and a local Swift package, so it stays small and readable |
| S01 welcome | 2026-11-19 | done | the logo (still a brief) | |
| price notice (fix 1) | 2026-11-19 | done | the price comes from a constant ($9.99, proposed in `launch/pricing.md`, not confirmed) until StoreKit gives the real one | |
| S02 instrument | 2026-11-19 | done | MIDI as a choice (S24) | |
| S03 experience and goal | 2026-11-19 | done | the placement test (fix 5); the goal is stored but not used yet | |
| S04 sound check | 2026-11-19 | partial | latency calibration (play along to a click) | AVAudioEngine taps trap under Swift 6 if the tap closure is created on the main actor; the mic pipeline is a separate non-isolated class for that reason |
| S05 paywall | | not started | everything: StoreKit 2, plans, restore | |
| S06 sign in | 2026-11-19 | partial | Sign in with Apple (needs a team and the capability) | Supabase answers the same error for a wrong and an expired code; the app tells them apart by the code's age. An account that already has a profile skips the name step and gets its progress back |
| S07 home | 2026-11-19 | partial | the course row for more than one course; streak (S19) | |
| S09 course path | 2026-11-19 | partial | song nodes and star gates | |
| S10 concept card | 2026-11-19 | done | short animations | |
| S11 static exercise | 2026-11-19 | done | MIDI input; the "I played it right" taps are counted but not uploaded | the staff is drawn by hand in Canvas; the treble clef is the Unicode glyph, check that it renders on device |
| S14 result | 2026-11-19 | done | timing score (comes with S12); "new best" badge | |
| Settings (part of S23) | 2026-11-19 | partial | manage subscription, privacy and terms links | |

## The vertical slice

Hear a note → mark it right → save it, end to end:

- **Hear:** `MicPipeline` taps the input at the hardware rate, analyses 2048-sample windows every 1024 samples on its own queue with YIN (`HandspanCore/PitchDetector.swift`), and `NoteTracker` turns frames into note-ons: two agreeing frames to confirm, out-of-tune frames ignored, re-strikes of the same key found by the level jumping back up.
- **Mark:** `LessonRun` waits for the right key. A wrong key never moves on and gets a hint ("That was E4. Aim two keys lower."). Stars come from notes right the first time: 90% → 3, 70% → 2, 40% → 1.
- **Save:** the attempt goes to the local store first, then uploads through `Backend.recordAttempts`, which is idempotent by `client_attempt_id`. Failed uploads wait on the device and the home screen says so.

Done when (from `architecture.md`): a real piano in a normal room passes the five-note exercise, the attempt appears in Postgres and a replay doesn't duplicate it. The first part needs a device and a piano; the Postgres part is in place (`backend.md`).

## Tests (HandspanCore)

Pass on the CI Mac (2026-11-19): about 50 cases across pitch names and staff positions, the detector on synthetic piano tones (C2 to C7, including a fundamental 20 times weaker than the second harmonic), silence and noise, the note tracker (confirmation, held notes, re-strikes), scoring and stars, the lesson flow, the seed course (unique UUIDs, notes on the staff, no banned words), the fake backend's sign-in states and idempotency, the local store and the course path unlocking.

## Content

`HandspanCore/Sources/HandspanCore/Resources/first-steps.json`: 5 lessons, 19 exercises, right hand C4 to G4. Middle C, C D E, steps on the staff, F and G, five-note lines. Every concept lesson has a theory card and most have a posture or fingering tip (fix 6). Lesson and exercise ids are fixed UUIDs (v5), ready to seed the `lessons` table.

## Next

1. Install on an iPhone (TestFlight once there is an Apple Developer account), play the first lesson on a real piano, save screenshots to `replica/clone-screens/`.
2. ~~`/replica-backend`~~ done 2026-11-19: see `backend.md`. Left for the dashboard: the code email template.
3. S12 moving stage and S13 pause menu, then S05 paywall with StoreKit 2.
