# Architecture: Handspan (working name, see `brand.md`), a rebuild of Simply Piano's core features

Reads: `replica/recon.md`, `replica/features.csv`. Confirmed scope: iOS (iPhone + iPad), a product to sell, an MVP with one free course and single-note recognition.

## Stack

| layer | choice | why |
| --- | --- | --- |
| app | **SwiftUI, iOS 26+, Swift 6** | iOS only, and the product is low-latency audio. AVAudioEngine and CoreMIDI are first-class in Swift; in Expo they would need a custom native module anyway. iOS 26 is the minimum because the design uses Liquid Glass (`.glassEffect`, `GlassEffectContainer`) with no fallback (see `replica/design/`). |
| audio in | **AVAudioEngine input tap + on-device pitch detection** (YIN or MPM, written in Swift with Accelerate/vDSP) | No audio leaves the device: lower latency, works offline, simpler privacy story than the original (which lists "Audio Data" as collected). |
| MIDI in | **CoreMIDI** (USB and Bluetooth LE MIDI via `CABTMIDICentralViewController`) | Exact notes, no recognition errors. The honest answer to "the mic gets octaves wrong". |
| notation | **own JSON note format + SwiftUI `Canvas` staff renderer**; MusicXML only as an authoring import | A full notation engine is a project of its own. The lessons need one or two staves, a cursor and colours. |
| playback | **AVAudioPlayerNode on the same engine** for backing tracks and the reference "Listen" sound (a SoundFont via `AVAudioUnitSampler`) | One clock for input, backing track and cursor. That is what keeps them in sync. |
| local store | **SwiftData** | Offline progress and a queue of attempts waiting to upload. |
| database | **Postgres on Supabase** | One managed database, row level security, cron, storage and functions in one place. |
| auth | **Supabase Auth, email one-time code** (`signInWithOtp`, 6 digits) plus **Sign in with Apple** | No passwords, same feel as the original's email code. Apple sign-in is expected on iOS and costs little. |
| payments | **StoreKit 2** auto-renewable subscriptions, verified server-side with the **App Store Server API** + **App Store Server Notifications v2** | Digital content sold in an iOS app must use in-app purchase. Stripe does not apply here. (RevenueCat is an optional swap if you want dashboards and paywall tests without the server work.) |
| content files | **Supabase Storage**, private bucket, signed URLs | Lesson JSON, song JSON, backing audio. Premium files are only signed for entitled accounts. |
| functions | **Supabase Edge Functions** (Deno/TypeScript) | Webhook, entitlement verification, signed URLs, push sending, account deletion. |
| jobs | **pg_cron** inside Supabase | Hourly streak rollover, reminder sending, a daily subscription check. No separate worker. |
| push | **APNs** direct from an edge function (token-based `.p8` key) | Practice reminders and streak nudges. |
| email | **Resend**, from your own domain | Sign-in codes (through Supabase's custom SMTP setting) and a weekly streak email later. |
| analytics and errors | **TelemetryDeck** (privacy-first) + **Sentry** | No ad tracking identifiers, unlike the original. That keeps the App Privacy label short. |
| hosting | Supabase (managed); the app ships through **TestFlight → App Store** | Nothing else to host. A marketing site comes in `/replica-launch`. |

One database, no microservices. The scoring of a play-through happens on the device; the server only stores results.

## Schema

Tables: **16**. Access rules: **Postgres row level security on every table** (`auth.uid()` = account id). Full SQL: `replica/schema.sql`. It loads cleanly into Postgres 16, and the tests listed below pass.

| table | owner | what it holds |
| --- | --- | --- |
| `accounts` | itself | one row per auth user, locale |
| `subscriptions` | account (read only) | App Store entitlement mirror: plan, status, `max_profiles`, `expires_at` |
| `app_store_events` | none (service role only) | every server notification once, by `notification_uuid` |
| `profiles` | account | learners under one account: adult or kid, input mode, learning path |
| `courses`, `lessons` | public metadata | course path, lesson kinds (`concept`, `exercise_set`, `song`, `star_gate`) |
| `songs`, `song_sections` | public metadata | **every song must carry `license` and `license_note`**: public_domain, original or licensed |
| `gate_songs` | public metadata | which song sections count toward a star gate |
| `attempts` | account (read only) | one finished play-through: accuracy, timing, stars, tempo, hands, input mode |
| `lesson_progress`, `song_progress` | account (read only) | best stars and done state, per profile |
| `streaks` | account (read only) | weekly streak, freezes, the profile's time zone |
| `favourites`, `devices`, `reminders` | account | My Library, APNs tokens, reminder schedule |

Rules enforced in the database, not the app:

- **Profile cap.** A trigger allows 1 profile without a plan or on individual, and `max_profiles` (Duo 2, Family 5) on an active plan.
- **Profile belongs to the account.** A trigger on `attempts`, `favourites` and `reminders` rejects a `profile_id` from another account. RLS on `account_id` alone would not catch this.
- **Clients never write learning data or subscriptions directly.** Progress goes through `record_attempts()`; entitlement through the webhook.
- **One target per attempt** (`num_nonnulls(lesson_id, song_section_id) = 1`), stars 0-3, accuracy 0-100, tempo 25-200%.
- **Song stars only count at 100% tempo without wait mode.** Slowed practice is practice, not a pass.

Tests run against a throwaway Postgres 16 with an `auth` stub:

1. A first profile is allowed and a second is rejected without a plan (`profile_limit_reached`).
2. A client insert into `subscriptions` is rejected by RLS.
3. `record_attempts` returns 1, and the same batch replayed returns 0. Progress becomes `done` with 3 stars and the streak starts at 1 week.
4. A second account sees 0 profiles, attempts and streaks of the first.
5. A second account recording into the first account's profile is rejected (`profile_not_in_account`).
6. An active family plan allows the second profile.
7. Streak: a practised week keeps the streak, an empty week spends a freeze (2 → 1), and three empty weeks with one freeze reset it to 0.

## API

The app reads public content metadata and its own rows straight from Supabase (PostgREST under RLS). Everything that needs a secret or a cross-table rule is an RPC or an edge function.

| method path | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| `auth.signInWithOtp` / `verifyOtp` (Supabase) | email code sign-in | anyone | email, then code | session | F01 |
| `auth.signInWithIdToken` (Apple) | Sign in with Apple | anyone | Apple identity token | session | F01 |
| `POST /rest/v1/accounts` | create the account row after first sign-in | signed in | locale | account | F01 |
| `GET/POST/PATCH/DELETE /rest/v1/profiles` | list, add, rename, remove learner profiles | signed in, own | name, kind, input_mode, learning_path | profile | F01, F06 |
| `GET /rest/v1/courses?published=eq.true&order=position` | course map | signed in | none | courses | F02 |
| `GET /rest/v1/lessons?course_id=eq.{id}&order=position` | a course's lesson path | signed in | course id | lessons | F02, F04 |
| `GET /rest/v1/songs?...` | song library with level and genre filters | signed in | filters | songs | F03 |
| `GET /rest/v1/song_sections?song_id=eq.{id}` | a song's sections | signed in | song id | sections | F03 |
| `GET /rest/v1/lesson_progress`, `song_progress`, `streaks` | own progress and streak | signed in, own | profile id | rows | F02-F04, F07 |
| `POST /functions/v1/content-url` | signed URLs for lesson or song files (1 hour), after checking `is_free` or `has_premium()` | signed in | list of lesson / section ids | `{id: url}`, or 402 for locked items | F02, F03, F05 |
| `POST /rest/v1/rpc/record_attempts` | save a batch of finished attempts, update progress and streak; idempotent by `client_attempt_id` | signed in, own profiles | attempts[], time zone | count inserted | F02-F04, F07 |
| `POST/DELETE /rest/v1/favourites` | heart a song | signed in, own | profile id, song id | row | F03 |
| `PUT /rest/v1/reminders` | set reminder days and time | signed in, own | weekdays, local time, time zone | row | F07 |
| `POST /rest/v1/devices` | register an APNs token | signed in, own | token, time zone | row | F07 |
| `POST /functions/v1/subscription-sync` | right after a purchase or restore: verify the signed transaction with the App Store Server API and upsert `subscriptions` | signed in | `jwsRepresentation` from StoreKit 2 | entitlement | F05 |
| `POST /functions/v1/delete-account` | delete everything for the account, including the auth user; tell the user to cancel the subscription in Settings (Apple does not allow server-side cancel) | signed in | confirmation | 204 | Settings |

Webhooks in:
- **App Store Server Notifications v2** → `POST /functions/v1/appstore-notifications`. Verify the JWS signature chain against Apple's root certificate, store `notification_uuid` in `app_store_events` (unique: retries are dropped), then upsert `subscriptions` by `original_transaction_id`. The relevant types are `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `DID_FAIL_TO_RENEW`, `GRACE_PERIOD_EXPIRED`, `EXPIRED`, `REFUND` and `REVOKE`.

Webhooks out: none.

Jobs (pg_cron):
- `roll_streaks()` **hourly**: closes finished weeks in each profile's time zone; a missed week spends a freeze or resets the streak; every 5 practised weeks earns a freeze (cap 10).
- `send-reminders` **every 15 minutes**: the edge function sends APNs to `reminders` where `next_fire_at <= now()`, then recomputes `next_fire_at` in the profile's time zone.
- `subscription-reconcile` **daily at 03:17 UTC**: re-checks with the App Store Server API any subscription past `expires_at` that is still marked active, in case a notification was lost.

Only Apple's and Supabase's public APIs with your own keys. Nothing from the original app's servers.

## The parts that bite

- **Note recognition latency and accuracy.** Budget: under 50 ms from key to colour change. Use 512-sample buffers at 48 kHz, and a one-time latency calibration in onboarding (S04): play along to a click and measure the offset. Single notes first; chords are a second milestone. Octave errors are the top complaint against the original, so test against recorded real pianos (upright, grand, cheap keyboard speakers) in a quiet and a noisy room before trusting any number.
- **Bluetooth headphones add 150-250 ms of output lag.** Detect AirPods and other Bluetooth routes with `AVAudioSession` and shift the scoring window, or warn the user. The original has a help article just for this.
- **Audio session interruptions.** Phone calls, Siri, other apps, unplugging a MIDI cable mid-stage: pause the stage and keep its state. Never lose an attempt.
- **Time zones.** Streak weeks and reminders run in the profile's own time zone (`timezone` on `streaks` and `reminders`). Store UTC and compute local dates in SQL with `at time zone`. Daylight saving moves reminder times: recompute `next_fire_at` after every send, never add 24 hours.
- **Streak rollover lag.** `roll_streaks` runs hourly, so a session in the first hour of a new week can land on the old week. Accept that at MVP, or call the rollover for that one profile at the top of `record_attempts`.
- **Idempotency.** Offline attempts can upload twice: `client_attempt_id` is unique. App Store notifications are retried: `notification_uuid` is unique, and upserts go by `original_transaction_id`.
- **Races.** Two devices on one family account finish the same lesson: `on conflict ... greatest(best_stars)` keeps the best and never overwrites with a worse score.
- **Trust.** Scores are computed on the device, so a jailbroken client can fake stars. That only affects that user's own progress. Never put money or public leaderboards on these numbers without server-side checks.
- **Content rights.** The `license` column is mandatory for a reason. Every song and backing track needs a written source: public domain composition *and* your own recording or arrangement. A modern edition of an old score can still be under copyright.
- **Kids profiles.** Under-13s bring COPPA (US), GDPR-K (EU) and Apple's Kids Category rules: no third-party analytics or ads in kid flows, and a parental gate before links and purchases. Keep kid profiles behind the adult account; the child never has their own login.
- **App Review.** Guideline 3.1.2 needs the plan, price and period on the paywall, a restore button, and links to terms and privacy. 5.1.1(v) needs account deletion in the app. 4.1 (copycats) is `/replica-brand`'s job.
- **Trials.** The original only offers a trial on the yearly plan, and the paywall defaults to it. That is a top billing complaint. Decide this in `/replica-launch`, but the schema already supports trials on any plan.
- **Storage size.** Backing audio is the heavy part: AAC 128 kbps is about 1 MB per minute. Download per course and cache, rather than shipping everything in the app bundle.
- **GDPR deletion.** `delete-account` removes the auth user, and every table cascades from `accounts`. Sentry and TelemetryDeck get no personal data, so nothing needs deleting there.
- **Search.** Not needed at MVP: about 20 songs, filter by level and genre. Add Postgres full-text search on `songs.title` and `composer` when the library passes 200.
- **Multi-tenancy.** None. One account is the boundary, enforced by RLS and the profile triggers.

## Build order

**1. Vertical slice: hear a note, mark it right, save it** (about 3 weeks)
- Screens: S04 (mic and latency check, ugly), S11 (static exercise: one staff, five notes, the keyboard hint strip), S14 (stars).
- Code: AVAudioEngine tap → pitch detector → note events; a hard-coded JSON lesson; the staff renderer; the scoring function; a SwiftData attempt queue.
- Backend: `accounts`, `profiles`, `courses`, `lessons`, `attempts`, `lesson_progress`, `record_attempts`, email code sign-in.
- Done when: a real piano in a normal room passes the five-note exercise, the attempt appears in Postgres, and a replay doesn't duplicate it.

**2. Must-haves** (17 rows in `features.csv`), by area
- Onboarding: S01, S02, S03, S04 (with calibration), S06.
- Courses: S07 course map, S09 lesson path, S10 concept intro.
- Player: S12 moving stage with backing track and cursor on one clock; S13 pause menu (resume, restart, listen, exit).
- Monetisation: S05 paywall with StoreKit 2, `subscription-sync`, `appstore-notifications`, `content-url`, restore purchases; `subscriptions`, `app_store_events`.
- Account: progress sync across devices; `delete-account` in S23.
- Content: the free course (about 12 lessons) and its exercises, all written fresh.

**3. Should-haves** (15 rows)
- Player: MIDI input (S24); chord recognition from the mic.
- Songs: S15 library and S16 sections; tempo, one hand, wait mode, metronome, finger numbers and scrubbing in S13; `songs`, `song_sections`, `song_progress`.
- Courses: S08 two learning paths; star gates (`gate_songs`).
- Engagement: S19 streak (`streaks`, `roll_streaks`); reminders (`devices`, `reminders`, `send-reminders`).
- Content: about 20 public-domain pieces in your own arrangements, with your own backing recordings.

**4. Could-haves** (9 rows)
- S25 touch keyboard course; S17 sheet music with auto scroll; favourites; S18 short daily session; S22 family profiles (the cap already works); S21 kids XP (with the parental gate); S20 challenges; printable sheet music; support chat.

**5. Fixes from `/replica-entrepreneur`**, once it has run. Leads from the recon to check against real reviews:
- the trial and billing defaults;
- octave and wrong-note acceptance;
- the lack of a monthly plan;
- users without a piano losing access after the first course;
- timing and theory taught too late.
