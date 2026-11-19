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

Sign-in uses a fake backend for now: any email, and any 6-digit code. `000000` shows the wrong-code state and `999999` the expired one.

## Test it

```
cd replica/app/HandspanCore && swift test
```

or Product › Test (⌘U) in Xcode: the shared `Handspan` scheme runs the HandspanCore tests.

## Where things stand

- **Not compiled yet.** This was written in a Linux container with no Swift toolchain. Expect a few compile errors on the first build; they are small and get fixed on the Mac. The pitch detector's algorithm was checked separately against synthetic piano tones (C2 to C7, weak fundamentals, 44.1 and 48 kHz): no octave errors.
- **The backend is fake** (`FakeBackend` in HandspanCore). `/replica-backend` swaps in Supabase behind the same `Backend` protocol, so no screen changes.
- **Design files.** `Handspan/Design/` started as a copy of `replica/design/swift/`. Edit the app copy from now on and keep `tokens.json` in step.

See `replica/build-log.md` for screen by screen status.
