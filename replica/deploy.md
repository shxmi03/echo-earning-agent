# Deploy checklist: Handspan (working name)

Date: 2026-11-20  Commit: 7226893 (main, after PR #22)  Go from user: not yet

**Result: not shippable to the App Store yet.** The app builds, its core flow passes UI tests on the simulator, the backend is live and the landing page is public. What blocks a release:
- Note recognition has never been tried on a real piano. That is the product's biggest risk, and two must-haves wait on it.
- The app has never run on a device.
- Everything in App Store Connect is still to do, and it needs your Apple Developer account.

Since the morning's version of this file (commit 10f72af), PRs #20 to #22 closed every code-only item it listed: the legal links in the app, a placeholder app icon, a full `og:image` URL, the course row on Home (S07), star gates on the lesson path (S09), and UI tests in CI.

Every result below comes from a check run on 2026-11-20 at 7226893, unless it says otherwise.

## Preflight (all must pass)

| check | result |
| --- | --- |
| tests green | **pass for what exists.** On GitHub's `macos-26` runner, PR #22's last run passed all four jobs: the app build, the `HandspanCore` tests (87 test functions), the UI tests (3) and the migrations with access rules on Postgres 17. Locally on Postgres 16 today, `supabase/tests/run.sh` reports "All database checks passed" with all 8 migrations. The UI tests cover onboarding to Home with the course map, lesson 1 on the screen keys through to the result, and the Settings legal links plus account deletion. They use the in-memory backend and no microphone, so they don't test recognition or the live backend. |
| no open S1 or S2 bugs | **unknown.** There is no `bugs.md`. Nothing failed in the simulator runs, but the app has never run on a device. |
| parity: all must-haves done | **fail.** `parity.py replica/features.csv` → 66.1 / 100, must-haves 15 of 17. The two open ones are both about recognition: octave-correct detection tested on real pianos, and a wrong note in a chord (single notes are handled; chords aren't). The paywall is built (StoreKit 2, restore, server check) and still marked partial until its products exist in App Store Connect. |
| rebrand sweep clean | **pass.** `sweep.py . --config replica/brand.json` → Clean. |
| store listing passes | **pass.** `listing.py replica/launch/listing.json` → 0 errors, 0 warnings. |
| production build passes | **partial.** The simulator build is green on CI. There is no signed archive, because that needs an Apple Developer team. |
| privacy policy and terms live, every processor listed | **pass, with two caveats.** Both answer 200 at https://handspan.vercel.app/privacy.html and `/terms.html`. The app links both from the paywall footer (App Review 3.1.2) and from Settings › About (`LegalLinks` in `app/Handspan/Home/PaywallView.swift`), and a UI test checks the Settings links. The privacy page names Supabase, Resend, Vercel and Apple, which matches what the app uses today. Caveats: a lawyer should read both pages, and they live on a vercel.app address under an uncleared name. |
| account deletion works | **pass on the simulator.** Settings → Delete account → confirm → back to the welcome screen is a UI test. On the live backend it calls the `delete-account` edge function (active, JWT required), and the database deletes everything with the account (tested). Still to see once on a device against the hosted project. |
| favicon, titles, OG image, emails, app icon are yours | **pass with a placeholder icon.** `AppIcon.appiconset` has light, dark and tinted 1024 px images made by `design/make_app_icon.py` (an arc over five keys, white on the Sky gradient), so a build can upload. It's a placeholder: the logo is still a brief (`brand.md`), so pick or commission the real mark before launch. The site's `og:image` is now a full URL with a large Twitter card; it still shows the design preview, not the real app. Favicon, title and the sign-in email template are ours. |

## Production

| item | status |
| --- | --- |
| Database | One hosted Supabase project, **handspan** (`ypvscfhwywxjnjzhcmqq`, Free plan, Frankfurt). All 8 migrations in `replica/supabase/migrations/` are applied, including today's `star_gate` (the first course is now lessons 1 to 5, the gate at 6, the song at 7). 0 users. The checklist wants a **separate production project with daily backups**, and the Free plan has no backups: before launch, either upgrade this project to Pro and develop on a branch or a second project, or create a production project and run the migrations there from CI. |
| Scheduled job | `roll_streaks` runs from pg_cron (1 job). |
| Edge functions | `appstore` (active, JWT off by design: Apple's notifications carry none, and `/sync` checks the user's token itself) and `delete-account` (active, JWT on). |
| Security advisor | Two notices, both intended: `app_store_events` has RLS on and no policy (only the service role touches it), and `record_attempts` is callable by signed-in users (it is the app's write path and checks `auth.uid()` itself). |
| Payments | StoreKit 2, not Stripe. **Not set up**: the Paid Applications agreement, the 4 subscriptions in group "Handspan" with a 1-week intro offer, the Server Notifications V2 URL (`…/functions/v1/appstore/notifications`), and the secrets `APPLE_APP_ID` (and `APPLE_BUNDLE_ID` if not `app.handspan.ios`). All of it needs your account; the steps are in `backend.md`. |
| Sign-in email | Not checked from here: the auth settings aren't readable with these tools. `backend.md` lists two dashboard steps: the code template, and **custom SMTP through Resend**. Without SMTP, Supabase only emails members of your organisation, so beta testers couldn't sign in. |
| Sign in with Apple | Not built. It needs the Apple team and a Services ID. |
| Waitlist | **Works.** On the hosted project, inside transactions that were rolled back: an anonymous insert is accepted and an anonymous read is refused (`permission denied`). 0 rows so far. |

## Domain

None yet. The site is at **https://handspan.vercel.app** (Vercel project `handspan` in team mallokka; the production alias is public, and per-deployment URLs sit behind Vercel login). Before a custom domain goes on it:
- **Trademark searches for "Handspan"** (USPTO classes 9, 41, 42; EUIPO; WIPO; Canada): not run. The page and now the app's legal links already use this name, which makes this the most expensive thing to undo.
- **Buy the domain.** gethandspan.com and handspanpiano.com had no record on 2026-11-10; confirm at a registrar. When it exists, change `LegalLinks.site` in the app and the `og:` URLs on the site in the same change.

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
- [ ] Core flow on a real iPhone and a real piano: onboarding → lesson 1 → result → the attempt in Postgres → a replay that doesn't duplicate it (the vertical slice's "done when" in `architecture.md`). The simulator half of this is now covered by the UI tests.

## Order from here

**Yours (the critical path; nothing else ships without it):**
1. Join the Apple Developer Program ($99 a year). Then create the app in App Store Connect with bundle id `app.handspan.ios` and put a TestFlight build on your iPhone.
2. Play the first course on a real piano, and on MIDI if you have a keyboard. Save the screens to `replica/clone-screens/`. Write down which notes it missed or wrongly accepted, and in which octave: this closes or reopens the two open must-haves.
3. Run the trademark searches, then buy the domain.
4. Set up Resend as the custom SMTP in Supabase.
5. Pick the real logo (from `brand.md`'s brief) to replace the placeholder icon.

**Claude's, any time (needs nothing from you):**
1. Wrong notes in chords: make a chord exercise fail when an extra wrong key sounds, with tests on synthetic chords.
2. Sentry and TelemetryDeck in the app, with the privacy page and App Privacy label updated in the same change.
3. A `bugs.md` from a full click-through of every screen, beyond the three UI tests.

Run this preflight again after the first TestFlight build.
