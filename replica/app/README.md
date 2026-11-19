# Handspan iOS app

SwiftUI, iOS 26+, Swift 6. The first flow: onboarding to the end of a lesson.

```
replica/app/
  Handspan.xcodeproj      open this in Xcode 26
  Handspan/               the app target (folder-synced: new files are picked up automatically)
    App/                  entry point, AppModel (state, sync, account)
    Audio/                microphone → pitch detection → notes
    Design/               Tokens.swift and Components.swift (the live copy; see below)
    Onboarding/           S01 welcome, price, S02 instrument, S03 experience and goal, S04 sound check, S06 sign in
    Home/                 S07 home, S09 course path, Settings with account deletion
    Lesson/               S10 concept card, S11 exercise with the staff, S14 result
  HandspanCore/           Swift package, no UIKit: pitch detection, note tracking, scoring,
                          lesson content, data layer, local store. Has the unit tests.
```

## Run it

1. Open `Handspan.xcodeproj` in Xcode 26.
2. Pick your team under Signing & Capabilities (the project ships with none) and, if you like, change the bundle id `app.handspan.ios`.
3. Run on an iPhone or iPad. The simulator works too, using the Mac's microphone, or choose "No piano yet" to play on the screen.

Sign-in goes to the real Supabase project "handspan" (`Handspan/App/SupabaseSettings.swift`, see `replica/backend.md`): a 6-digit code arrives by email. To try every screen without email, launch with the environment variable `HANDSPAN_FAKE_BACKEND=1` (Edit Scheme › Run › Arguments): then any 6-digit code works, `000000` shows the wrong-code state and `999999` the expired one.

## Test it

```
cd replica/app/HandspanCore && swift test
```

or Product › Test (⌘U) in Xcode: the shared `Handspan` scheme runs the HandspanCore tests.

No Mac that runs Xcode 26? `.github/workflows/ios.yml` builds the app for the iOS Simulator and runs `swift test` on a GitHub-hosted Mac (`macos-26`) on every push that touches `replica/app/`. The results show on the pull request; a failed build uploads its log.

## Where things stand

- **Builds and tests pass on CI** (GitHub `macos-26`, Xcode 26.6). Not yet tried on a device or a real piano. The pitch detector passes on synthetic piano tones (C2 to C7, weak fundamentals, 44.1 and 48 kHz) with no octave errors.
- **The backend is Supabase** (`SupabaseBackend` in HandspanCore, plain URLSession). `FakeBackend` stays for previews, tests and `HANDSPAN_FAKE_BACKEND=1`. Schema, functions and tests: `replica/supabase/`.
- **Design files.** `Handspan/Design/` started as a copy of `replica/design/swift/`. Edit the app copy from now on and keep `tokens.json` in step.

See `replica/build-log.md` for screen by screen status.
