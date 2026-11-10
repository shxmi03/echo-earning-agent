# Components

Style: native iOS 26. Liquid Glass on the floating control layer; frosted cards over a soft sky gradient for content. The reference is the user's own style image (two "Today" screens, light and dark), not the original app. Nothing here comes from the original's look: its purple brand, mascot, illustrations and copy are all excluded.

Tokens: `tokens.json` (source of truth), `tokens.css` (preview and landing page), `swift/Tokens.swift`. Primitives: `swift/Components.swift`. Visual check: `preview.html` and `preview.png`.

## Rules for the whole app

- **Glass is for controls, not content.** Tab bar, toolbars, floating buttons, the player HUD, the pause menu and sheets use Liquid Glass (`.glassEffect`, `.buttonStyle(.glass)`). Cards, lists and the staff use frosted or solid surfaces. Never glass on glass. Neighbouring glass shapes go in one `GlassEffectContainer` so they blend and morph.
- **One solid primary action per screen.** It is the black capsule (white in dark mode). Everything else is glass, plain text or a native control.
- **Native first.** `TabView` (glass tab bar, minimises on scroll), `NavigationStack` with large titles where there is no custom header, `.sheet` with detents, `Toggle`, `Slider`, `Picker`, `Menu`, `ShareLink`, `.searchable`. Do not redraw what iOS draws.
- **Sky gradient only on Home, Songs and Progress.** Onboarding, paywall, settings and the player sit on `bg` or `paper`. The player needs a calm page.
- **Header text sits only in the sky's top band.** `on-sky` passes contrast against `sky-top` only. If a header scrolls down into `sky-mid`, switch it to `text`.
- **Dynamic Type everywhere.** Text styles only, no fixed sizes. Layouts are tested at the largest accessibility size, where the week strip wraps to two rows and the focus card's CTA goes full width.
- **Colour is never the only signal.** Note states have a symbol as well as a colour (check, cross, arrow). Practised days have a dot *and* a VoiceOver value.
- **Reduce Motion**: springs become 0.2 s crossfades, there is no press scaling, and stars appear without bounce. **Reduce Transparency**: frosted cards become solid `surface`; the system handles glass.
- **Hit targets** are at least 44×44 pt.

---

## Screen header
```
ScreenHeader
  variants  title + subtitle; + trailing glass icon button; + trailing progress ring
  tokens    title (28 regular) on-sky / on-sky-muted; padding x card-padding, top header-top
  states    default; scrolled (fades into the nav bar's inline title)
  a11y      the two lines are one header element ("Today, Tuesday Nov 3")
  used on   S07, S15, S19
```

## Primary button (solid capsule)
```
Button(.primary)
  sizes     height 52, padding x 24; full width at accessibility sizes or in the paywall
  states    default, pressed (scale 0.97, snappy), disabled (40% opacity), loading (spinner + dimmed label, label still read)
  tokens    bg accent, text on-accent, headline; radius pill
  a11y      real Button; the loading state adds "Loading" via accessibilityValue
  used on   S05 (Start trial), S07/S09 (Start lesson), S14 (Continue), S06 (Send code)
```

## Glass buttons
```
GlassIconButton / .buttonStyle(.glass) / .buttonStyle(.glassProminent)
  variants  icon circle 48 (settings, close, pause); text capsule (secondary actions: "Listen", "Restart")
            glassProminent with tint, at most one per screen and only when there is no solid primary
  states    default, pressed (system interactive glass), disabled
  a11y      icon-only buttons always carry accessibilityLabel
  used on   S07 (settings), S12/S13 (pause, listen, restart, exit), S17 (auto scroll)
```

## Option card (onboarding choice)
```
OptionCard
  variants  icon + title + one line; title only
  states    unselected (frosted, border hairline), selected (2pt tint border + check, surface-raised), pressed, focused
  tokens    radius inner 20, padding 20, headline + subheadline text-muted
  a11y      Button with .isSelected trait; the group is one radio-like list
  used on   S02, S03, S08, S18
```

## Plan card (paywall)
```
PlanCard
  variants  yearly, monthly, duo, family
  states    unselected, selected (tint border + check), with badge ("Best value"), trial ("7 days free, then €X/yr" in text, never only in fine print)
  tokens    frosted card, radius inner; price headline monospacedDigit
  rules     price, period and renewal shown in full on the card (App Review 3.1.2); default selection is the plan the user tapped, not auto-yearly
  used on   S05
```

## Focus card (stacked deck)
```
FocusCard
  layers    sunken container holding: top row (course progress ring 20pt + title + %),
            main frosted card (eyebrow, title-strong, subheadline summary, CTA + duration),
            bottom row ("Up next" + next lesson)
  states    ready; in progress ("Resume", progress shown); course finished (CTA "Choose next course"); locked (CTA "Unlock with Premium", glass)
  motion    CTA morphs into the player HUD on tap (matchedGeometry / glassEffectID, smooth 0.4)
  a11y      the main card is one element: "Lesson 4, Middle C and friends, 6 minutes"; the CTA stays separate
  used on   S07
```

## Course card and course row
```
CourseCard
  variants  free, premium; path tag (Foundation, Melody, Chords)
  states    locked (lock symbol + "Premium"), in progress (ring), done (check), current (raised)
  tokens    frosted card radius inner; title3; ring 32pt
  used on   S07 (horizontal scroll), S08
```

## Journey node (lesson path)
```
JourneyNode
  variants  concept, exercise set, song, star gate ("4 / 6 ★"), video
  states    locked (dimmed + lock), current (raised, tint ring, gentle pulse off under Reduce Motion), done (check + best stars)
  a11y      "Lesson 3, Two hands, done, 3 stars"
  used on   S09
```

## Staff / notation view
```
StaffView
  variants  static (one bar, no time pressure), moving (scrolls under a fixed cursor), sheet page (auto scroll)
  note states upcoming (ink), target (tint + ▼), correct (success + ✓), wrong (danger + ✕), heard (text-muted)
  tokens    page paper, ink; staff lines ink 30%; note colour change Motion.keyFeedback (60 ms linear)
  rules     the staff never sits on glass or on the sky gradient; it is drawn in Canvas, one layer, no shadows
  a11y      VoiceOver reads the current target note ("Play C, right hand, finger 1") and the result after each note
  used on   S11, S12, S17
```

## Keyboard strip
```
KeyboardStrip
  variants  2 octaves (phone), 3 octaves (iPad), full touch keyboard (S25, playable)
  states    per key: idle, target, correct, wrong, heard; pressed (touch variant)
  tokens    white keys surface-raised, black keys ink; state colours as NoteState
  a11y      hidden from VoiceOver in hint mode (the staff carries the info); playable in the touch variant with direct touch
  used on   S11, S12, S25
```

## Cursor
```
Cursor
  variants  moving-stage line (tint, 2pt, fixed at 30% of the width); sheet cursor (tint, follows the beat)
  motion    driven by the audio clock, not by SwiftUI animation
  used on   S12, S17
```

## Player HUD and pause menu
```
PlayerHUD (Liquid Glass, GlassEffectContainer)
  parts     pause circle + status capsule (progress, tempo %)
  states    playing; paused: the pause button morphs into the pause menu (glassEffectID)
PauseMenu (glass sheet, medium detent)
  course    Resume (solid primary), Restart, Listen, Exit
  song      + Tempo slider (25–200%, steps of 5), Hands picker (Left / Right / Both), Wait for me toggle, Metronome toggle, Finger numbers toggle
  a11y      sheet traps focus; Escape / two-finger scrub closes it
  used on   S12, S13
```

## Result
```
ResultView
  parts     StarRow (reveals one star at a time, reward spring, success haptic), accuracy and timing bars, Continue (primary), Try again (glass)
  states    pass (1–3 stars), not yet (0 stars: "Almost. Try the tricky bar at 80%?" with a one-tap tempo drop), new best (badge)
  rules     never red "Fail" language; a missed note is information, not a failure
  used on   S14
```

## Song card and song list
```
SongCard
  variants  row (list), tile (grid on iPad); level tag; composer line; XP tag on kid profiles
  states    free, premium (lock), "a bit hard for now" (info symbol, still playable), done (best stars), favourite (heart)
  rules     every song shows its composer; licensing lives in the data, not the UI
  used on   S15, S16, S20
```

## Week strip and streak
```
WeekStrip
  parts     "This week" + date range; 7 day cells (weekday letter caption, date title3, practised dot tint)
  states    today raised (surface-raised chip, matchedGeometry when the week changes), practised (dot), future (muted)
StreakBadge
  parts     flame symbol + weeks count (rounded number), freezes as small snowflake symbols
  states    active, frozen this week, reset (no shame copy: "New streak starts today")
  used on   S07, S19
```

## Progress ring
```
ProgressRing
  sizes     20 (inline, no label), 32 (course card), 96 (header)
  tokens    stroke 3, on-sky in the header, text inside cards; numericText transition
  used on   S07, S09, S19
```

## Celebration and badge
```
Celebration (full-screen cover over a blurred page)
  variants  lesson done, course done, level up (kids), badge (challenges)
  motion    reward spring + symbolEffect(.bounce); particles only when Reduce Motion is off; shown once per milestone
  a11y      announced with an accessibility notification; Continue is focused first
  used on   S14, S20, S21
```

## Profile avatar
```
ProfileAvatar
  variants  adult (initials on tint), kid (SF Symbol animal on a soft colour), add (+ glass)
  states    selected (2pt ring), default
  used on   S22, S07 header
```

## Code input
```
CodeField
  parts     6 cells, one TextField with .oneTimeCode content type, so iOS offers the code from Mail
  states    empty, filling, complete (auto-submit), error (danger border + message under, shake off under Reduce Motion), resend timer
  used on   S06
```

## Listening meter
```
ListeningMeter
  parts     a level bar + a note name as it is heard ("C4"), the latency calibration ("Tap with the click")
  states    silent ("Play any key"), hearing, too quiet, too noisy, mic denied (shows a Settings button)
  used on   S04, S24
```

## Toast and banner
```
Toast (glass capsule, top, auto-dismiss 3 s)
  variants  info, success, offline ("Saved on this iPhone, will sync"), error
  a11y      posted as an announcement; never the only place an error is shown
Banner (frosted card)
  variants  event, trial ending, update needed
  used on   all
```

## Tab bar
```
Native TabView (iOS 26 glass tab bar)
  tabs      Learn (S07), Songs (S15), Practice (S18), You (S19/S23)
  behaviour .tabBarMinimizeBehavior(.onScrollDown); Search role tab on Songs
  used on   app root
```
