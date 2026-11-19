# Deploy checklist: Handspan (working name)

Date: 2026-11-19  Commit: 2207c76 (main, after PR #6)  Go from user: not yet, and the preflight stops here

**Result: not deployable. There is no app yet.** The repo has the plans, the design system, the launch copy and a static landing page. It has no app code: no Xcode project, no tests, no build. `/replica-build` is the step that was skipped between design and launch. The landing page could go live on its own, but only after the items in "Landing page only" are done.

## Preflight (all must pass)

| check | result |
| --- | --- |
| e2e suite green | **fail**: no app and no tests (`/replica-test` hasn't run) |
| no open S1 or S2 bugs | n/a: nothing to test |
| parity: all must-haves done | **fail**: `parity.py replica/features.csv` → 0.0 / 100, must-haves 0 of 17 done |
| rebrand sweep clean | pass: `sweep.py . --config replica/brand.json` → Clean (exit 0) |
| store listing passes | pass: `listing.py replica/launch/listing.json` → 0 errors, 0 warnings |
| production build passes | **fail**: no Xcode project to archive |
| privacy policy and terms live, every processor listed | **fail**: not written. Processors to list: Supabase, Resend, TelemetryDeck, Sentry, Apple (payments) |
| account deletion works | **fail**: not built (Apple requires it in the app) |
| favicon, titles, OG image, emails, app icon are yours | partial: the landing page has its own favicon, title and OG image. The app icon and the logo are still a brief (`brand.md`), and the OG image is the design preview |

Also open from `launch-plan.md`: **the trademark searches for "Handspan" haven't been run**, and no domain has been bought.

## Production

Not started; it depends on the app. Per `architecture.md` it will be:

- [ ] Supabase: a separate production project, backups on (Pro plan for daily backups), migrations from `replica/schema.sql` run by CI, not by hand
- [ ] Edge function secrets: App Store Server API key (`.p8`, key id, issuer id), APNs key, Resend API key, Sentry DSN. Names to go in an `.env.example` once the backend exists
- [ ] Payments: **StoreKit, not Stripe** (iOS digital content). The 4 subscriptions from `launch/pricing.md` in App Store Connect, Server Notifications v2 pointed at `appstore-notifications`, one sandbox purchase and refund tested
- [ ] Sign in with Apple: the Services ID and the production redirect; no Google OAuth in this app
- [ ] Email: the sending domain verified in Resend, set as Supabase's custom SMTP

## Landing page only (could go live before the app)

`replica/launch/site/` is a static folder that any static host serves as is.

| step | who | status |
| --- | --- | --- |
| Trademark screening for Handspan (USPTO, EUIPO, WIPO) | you | not done: a public page under an uncleared name is the one step that's expensive to undo |
| Buy the domain (gethandspan.com or handspanpiano.com had no record on 2026-11-10; confirm at a registrar) | you | not done |
| Privacy policy and terms pages (`privacy.html`, `terms.html`) | Claude can draft; a lawyer should read them | not done |
| Waitlist endpoint, set as `data-endpoint` on the form | Claude can write it (Supabase edge function plus a `waitlist` table, or a form service) | not done |
| Support email at the domain | you | not done |
| Host: Vercel, Netlify or Cloudflare Pages, root `replica/launch/site`, no build step | you sign in and connect the repo; Claude writes the config | not done |

DNS once the domain and host exist (Vercel shown; others give their own values):

| record | name | value |
| --- | --- | --- |
| A | @ | the apex IP shown in Vercel's domain settings |
| CNAME | www | `cname.vercel-dns.com` |
| TXT | @ | SPF from Resend (when email is set up) |
| CNAME/TXT | per Resend | DKIM, 3 records from Resend |
| TXT | _dmarc | `v=DMARC1; p=none; rua=mailto:you@yourdomain`, tightened to `quarantine` once reports are clean |

Canonical host: the apex, with www redirecting to it. HTTPS is automatic on all three hosts.

## Watch (after anything goes live)

- [ ] error tracking: Sentry (app, edge functions)
- [ ] uptime: the landing page and `subscription-sync`
- [ ] analytics: TelemetryDeck in the app; for the site, a cookieless counter (no cookie banner needed)
- [ ] core flow done on the live site, desktop and phone

## Order from here

1. `/replica-build`: the Xcode project, app shell, then the core flow (onboarding → first lesson → player → result) as a vertical slice, built from `design/swift/`.
2. `/replica-backend`: Supabase from `schema.sql`, auth, StoreKit sync, the reminder job.
3. `/replica-test`, then come back here.

In parallel, on your side: run the trademark searches, buy the domain and enrol in the Apple Developer Program ($99 a year).
