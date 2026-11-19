# Backend

Supabase project **handspan** (ref `ypvscfhwywxjnjzhcmqq`, Free plan, eu-central-1 Frankfurt), created 2026-11-19 in the user's organisation. Everything that defines it is in `replica/supabase/`:

```
supabase/
  config.toml              local `supabase start` settings: 6-digit email code, 10 minute expiry, rate limits
  templates/code.html      the sign-in email: shows {{ .Token }}, no link
  migrations/              applied to the hosted project in this order
    ..000000_schema.sql      the 16 tables, RLS, triggers, record_attempts, roll_streaks (was replica/schema.sql)
    ..000100_backend.sql     accounts row for every new auth user, tighter grants, pg_cron job for roll_streaks
    ..000200_first_course.sql  the "First steps" course and its 5 lessons, same UUIDs as the app's JSON
    ..000300_hardening.sql   fixes from Supabase's security advisor: no RPC access to trigger/job functions
  functions/delete-account/  edge function: deletes the auth user, everything cascades
  tests/run.sh             applies the migrations to an empty Postgres and runs tests/rls_test.sql
```

`replica/schema.sql` is kept as the original design; **the migrations are the source of truth from now on.** A schema change is a new file in `migrations/`, never an edit to an applied one.

## What the app does

`HandspanCore/SupabaseBackend.swift` implements the same `Backend` protocol as `FakeBackend`, with URLSession and no SDK:

| call | endpoint |
| --- | --- |
| send code | `POST /auth/v1/otp` `{email, create_user: true}` |
| check code | `POST /auth/v1/verify` `{type: "email", email, token}` |
| refresh | `POST /auth/v1/token?grant_type=refresh_token`, a minute before expiry and once after any 401 |
| existing profile (reinstall, second device, "I have an account") | `GET /rest/v1/profiles?order=created_at.asc&limit=1` |
| progress for the course map | `GET /rest/v1/lesson_progress?profile_id=eq.…` |
| new profile | `POST /rest/v1/profiles` (the cap trigger answers `profile_limit_reached`) |
| save lessons | `POST /rest/v1/rpc/record_attempts` `{batch, tz}`, at most 200 per call, idempotent by `client_attempt_id` |
| delete account | `POST /functions/v1/delete-account` |

Tokens live in the Keychain (`KeychainTokenStore`, this device only, after first unlock), never in the JSON local store. The project URL and publishable key are in `Handspan/App/SupabaseSettings.swift`: both are public by design. Clear the key, or launch with `HANDSPAN_FAKE_BACKEND=1`, to go back to the fake.

Supabase answers `otp_expired` for a wrong code and an old one alike, so the app tells them apart itself (code older than 10 minutes → "expired") and stops after 5 wrong codes until a new one is sent.

## Set up once in the dashboard (not possible through the API tools here)

1. **Authentication → Emails → Templates:** in both **Magic link** and **Confirm signup**, replace the body with `supabase/templates/code.html` (it must contain `{{ .Token }}`), subject "Your Handspan code". Without this the email holds a link and no code.
2. **Authentication → Sign In / Providers → Email:** email OTP length **6**, expiry **600** seconds.
3. **Before anyone outside the team signs in: custom SMTP** (Authentication → Emails → SMTP settings) with Resend from your own domain. Supabase's built-in sender only delivers to members of your Supabase organisation and only a few emails an hour.
4. Sign in with Apple, later: Authentication → Providers → Apple, with your own Services ID and key.

## Checks

- `supabase/tests/run.sh` on Postgres 16 locally and 17 on GitHub (`.github/workflows/supabase.yml`): new user gets an account row; signed-in users read the published course; a second profile without a plan is refused; `record_attempts` inserts 1 then 0 on replay and marks the lesson done with 3 stars; clients can't write attempts or subscriptions or run `roll_streaks` / `has_premium`; account B sees none of A's profiles, attempts, progress or streak, can't record into A's profile and can't rename it; signed-out visitors read nothing and can't call the RPC; deleting the auth user deletes everything.
- On the hosted project (2026-11-19, inside a rolled-back transaction): the same record_attempts call returned 1 and a second account saw 0 profiles and 0 progress rows.
- Supabase security advisor after hardening: two notices left, both intended. `app_store_events` has RLS and no policy (service role only), and `record_attempts` is callable by signed-in users (it's the app's write path and checks `auth.uid()` itself).
- `SupabaseBackendTests` (HandspanCore): request shapes, code states, rate limit, offline, refresh before expiry, retry after 401, revoked refresh token, wrong account, profile restore, profile cap, account deletion.

## Not done yet

- App Store payments: `subscription-sync`, `appstore-notifications`, `content-url` edge functions come with S05 (paywall, StoreKit 2).
- Reminders and push (`send-reminders`, APNs key).
- Sign in with Apple.
- Backups: the Free plan has none you can restore yourself. Move to Pro before launch for daily backups.

## Security checklist

- [x] secrets only in env vars: the app holds only the publishable key; the service role key exists only inside the edge function's environment
- [x] input validated on the server: check constraints on every column, `record_attempts` checks the batch shape and size
- [x] authorisation on every read and write, tested with a second account (locally and on the hosted project)
- [~] rate limits on auth: Supabase's own (`config.toml` and the dashboard). Code checking stops after 5 wrong codes on the device
- [ ] webhooks verify signatures: no webhooks yet (App Store notifications come with S05)
- [x] uploads: none
- [x] no user data in URLs or logs: profile id in a query string only, the edge function logs no email or id
- [x] dependencies: none in the app; the edge function uses `@supabase/supabase-js@2` only
- [ ] privacy policy lists every processor: Supabase (database, auth), later Resend, Apple. Write it before TestFlight
