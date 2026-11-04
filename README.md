# Hystranger

Mobile-first travel discovery and travel-buddy matching platform.

## Current product foundation
- Trip discovery and travel-buddy discovery.
- Host approval (default) and instant-join modes.
- Email magic-link authentication integration.
- Trip publishing and transactional join / approval RPCs.
- PostgreSQL tables, row-level security, verification-field protection, reports and blocks.
- Installable PWA shell with standalone display mode, manifest, service worker, safe-area spacing and mobile bottom navigation.

## Stack
Next.js 15, React 19, TypeScript, Tailwind CSS 4, Supabase Auth and PostgreSQL.

## Local setup
1. Install Node.js 20 or newer.
2. Copy `.env.example` to `.env.local`.
3. Set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
4. Run `npm install`, then `npm run dev`.
5. Run the SQL files in Supabase SQL Editor, in order: `supabase/migrations/001_full_schema.sql`, then `supabase/migrations/002_security_hardening.sql`.
6. Configure Supabase Auth Site URL and redirect URLs for localhost and your production domain. Enable email magic links. Configure Google and phone OTP only after provider credentials and SMS delivery are ready.

## Deploy
Add the two public Supabase environment variables to the hosting provider. Never put a service-role key in browser code or commit secrets. GitHub Actions runs a Next.js production build on pushes and pull requests.

## Not yet production complete
The current UI is a working foundation, not a finished production marketplace. Realtime chat UI/subscriptions, buddy-to-buddy connection workflow, profile editing, media upload, admin moderation console, identity-verification provider, push notifications, rate limiting/CAPTCHA, legal pages, privacy/deletion workflows and end-to-end tests remain to be implemented and tested. Sample trip cards are demo data and cannot be joined. Google / phone sign-in require provider configuration.

## Safety
Verification flags are not user-editable. A verification badge must not be treated as identity proof until a trusted provider is integrated. The app does not dispatch emergency services. Complete moderation, incident response, retention and deletion controls before public launch.
