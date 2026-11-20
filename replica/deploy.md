# Deploy checklist: Handspan (working name)

Date: 2026-11-20  Commit: 10f72af (main, after PR #18)  Go from user: not yet

**Result: not shippable to the App Store yet.** The app exists and builds, the backend is live and the landing page is public. What blocks a release:
- 4 must-have features are not finished.
- The app has never run on a device or on a real piano.
- It has no app icon.
- Everything in App Store Connect is still to do, and it needs your Apple Developer account.

The previous version of this file (2026-11-19, commit 2207c76) said "there is no app yet". That is no longer true: PRs #7 to #18 built the app, the backend and the landing page.

Every result below comes from a check run on 2026-11-20, unless it says otherwise.

## Preflight (all must pass)

| check | result |
| --- | --- |
| tests green | **partial**. `HandspanCore` unit tests (about 50) and the simulator build pass on GitHub's `macos-26` runner (iOS workflow run 30, commit 8027bba, the last commit that touched `replica/app/`). The database migrations and access rules pass on CI (run 13, 10f72af) and locally on Postgres 16 today (`supabase/tests/run.sh`: "All database checks passed"). There are **no UI or end-to-end tests** of the app yet: `/replica-test` hasn't run. |
| no open S1 or S2 bugs | **unknown**. There is no `bugs.md`, and the app has never run on a device. |
| parity: all must-haves done | **fail**. `parity.py replica/features.csv` → 60.6 / 100, must-haves 13 of 17. Open: the course map (one course, no course row), the lesson path (no star gates), the paywall (needs App Store Connect), and mic recognition on a real piano (synthetic tones only). |
| rebrand sweep clean | **pass**. `sweep.py . --config replica/brand.json` → Clean (exit 0). |
| store listing passes | **pass**. `listing.py replica/launch/listing.json` → 0 errors, 0 warnings. |
| production build passes | **partial**. The simulator build is green on CI. There is no signed archive, because that needs an Apple Developer team. |
| privacy policy and terms live, every processor listed | **partial**. Both answer 200 at https://handspan.vercel.app/privacy.html and `/terms.html`. The privacy page names Supabase, Resend, Vercel and Apple, which matches what the app uses today. Still to do: the app doesn't link to it yet (`LegalLinks.privacy = nil` in `app/Handspan/Home/PaywallView.swift:189`, and App Review 3.1.2 wants the link on the paywall); a lawyer should read both pages; they live on a vercel.app address under an uncleared name. |
| account deletion works | **partial**. It's built: Settings → `AppModel.deleteAccount` → the `delete-account` edge function (active, JWT required). The database deletes everything with the account (tested). It has not been run end to end on a device. |
| favicon, titles, OG image, emails, app icon are yours | **fail on the app icon**. `AppIcon.appiconset` has the three slots and no images, and the App Store rejects a build without an icon. The logo is still only a brief (`brand.md`). The site's favicon, title and sign-in email template are ours. The site's `og:image` is a relative path (`preview.png`, which social crawlers ignore; it needs a full URL) and shows the design preview, not the real app. |

## Production

| item | status |
| --- | --- |
| Database | One hosted Supabase project, **handspan** (`ypvscfhwywxjnjzhcmqq`, Free plan, Frankfurt). All 7 migrations in `replica/supabase/migrations/` are applied, the same list as the repo. It holds 0 users, 1 published course and 6 lessons. The checklist wants a **separate production project with daily backups**, and the Free plan has no backups: before launch, either upgrade this project to Pro and develop on a branch or a second project, or create a production project and run the migrations there from CI. |
| Scheduled job | `roll_streaks` runs from pg_cron (1 job). |
| Edge functions | `appstore` (v2, active, JWT off by design: Apple's notifications carry none, and `/sync` checks the user's token itself) and `delete-account` (v2, active, JWT on). |
| Security advisor | Two notices, both intended: `app_store_events` has RLS on and no policy (only the service role touches it), and `record_attempts` is callable by signed-in users (it is the app's write path and checks `auth.uid()` itself). |
| Payments | StoreKit 2, not Stripe. **Not set up**: the Paid Applications agreement, the 4 subscriptions in group "Handspan" with a 1-week intro offer, the Server Notifications V2 URL (`…/functions/v1/appstore/notifications`), and the secrets `APPLE_APP_ID` (and `APPLE_BUNDLE_ID` if not `app.handspan.ios`). All of it needs your account; the steps are in `backend.md`. |
| Sign-in email | Not checked from here: the auth settings aren't readable with these tools. `backend.md` lists two dashboard steps: the code template, and **custom SMTP through Resend**. Without SMTP, Supabase only emails members of your organisation, so beta testers couldn't sign in. |
| Sign in with Apple | Not built. It needs the Apple team and a Services ID. |
| Waitlist | **Works.** On the hosted project, inside transactions that were rolled back: an anonymous insert is accepted and an anonymous read is refused (`permission denied`). The list has 0 rows, so no real signup has arrived yet. |

## Domain

None yet. The site is at **https://handspan.vercel.app** (Vercel project `handspan` in team mallokka; the production alias is public, and per-deployment URLs sit behind Vercel login). Before a custom domain goes on it:
- **Trademark searches for "Handspan"** (USPTO classes 9, 41, 42; EUIPO; WIPO; Canada): not run. The page is already public under this name, which makes this the most expensive thing to undo.
- **Buy the domain.** gethandspan.com and handspanpiano.com had no record on 2026-11-10; confirm at a registrar.

DNS once the domain exists (Vercel shows its own values):

| record | name | value |
| --- | --- | --- |
| A | @ | the apex IP in Vercel's domain settings |
| CNAME | www | `cname.vercel-dns.com` |
| TXT | @ | SPF from Resend |
| CNAME/TXT | per Resend | DKIM, 3 records |
| TXT | _dmarc | `v=DMARC1; p=none; rua=mailto:you@yourdomain`, tightened to `quarantine` once reports are clean |

The canonical host is the apex, with www redirecting to it. HTTPS is automatic on Vercel.

## Watch

- [ ] Error tracking: Sentry is **not in the app or the edge functions yet**.
- [ ] Analytics: TelemetryDeck is **not in the app yet**. When either one goes in, add it to `privacy.html` and to the App Privacy label in the same change.
- [ ] Uptime: the landing page and `appstore/sync`.
- [ ] Core flow on a real iPhone and a real piano: onboarding → lesson 1 → result → the attempt in Postgres → a replay that doesn't duplicate it (the vertical slice's "done when" in `architecture.md`).

## Order from here

**Yours (the critical path; nothing else ships without it):**
1. Join the Apple Developer Program ($99 a year). Then create the app in App Store Connect with bundle id `app.handspan.ios` and put a TestFlight build on your iPhone.
2. Play the first course on a real piano, and on MIDI if you have a keyboard. Save the screens to `replica/clone-screens/`. This is the test for the biggest risk, recognition: write down which notes it missed or wrongly accepted.
3. Run the trademark searches, then buy the domain.
4. Set up Resend as the custom SMTP in Supabase.

**Claude's, any time (needs nothing from you):**
1. Link the privacy policy and terms from the app (paywall and Settings), and give `og:image` a full URL.
2. Finish the two code-only must-haves: the course row on Home (S07) and star gates on the lesson path (S09).
3. `/replica-test`: UI tests of the core flow on the simulator in CI, and a `bugs.md`.
4. A placeholder app icon from the logo brief, so TestFlight builds upload. The real logo still needs a designer or your own pick.

Run this preflight again after the first TestFlight build.
