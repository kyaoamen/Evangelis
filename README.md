# Evangelis

L'application de votre église : one platform hosting many churches. Each church gets its own branded space, and members sign in to the church they belong to.

| Folder | What it is | Stack |
| --- | --- | --- |
| [`app/`](app/) | Member app: Android, iOS and installable web app (PWA), FR/EN | Flutter, Riverpod, go_router |
| [`admin/`](admin/) | Church back-office for staff, plus the platform admin area | Next.js, Tailwind |
| [`supabase/`](supabase/) | Database schema, row-level security, RPCs, Edge Function, tests | Postgres (Supabase) |
| [`scripts/`](scripts/) | App build script and offline Bible converter | Bash, Node |

## Pilot

Pilot churches: Église Ambassade du Royaume de Dieu (20 members) and Église Baptiste La Moisson (400 members).

Members can join a church, register for events (QR ticket), read announcements and the offline Bible, and send feedback from the app. Staff use the back-office to manage branding, members, events, announcements and check-in, and to read feedback.

## Set up the backend (Supabase)

1. Create a Supabase project in an EU region.
2. Open SQL Editor → New query, paste the whole of `supabase/pilot_setup.sql` and click Run (or use `supabase db push` with the CLI). `supabase/seed.sql` adds a demo church for testing only.
3. Authentication → Email templates → "Magic Link": include `{{ .Token }}` so people receive the 6-digit code.
4. Authentication → URL configuration: set the Site URL to the deployed back-office address.
5. Make yourself platform admin: `insert into platform_admins (user_id) select id from auth.users where email = 'you@example.com';`
6. Offline Bible: build `LSG1910.json` and `KJV.json` with `scripts/build_bible_json.mjs` and upload them to the public `bible` storage bucket.
7. Push notifications (optional): deploy `supabase/functions/send-announcement-push` and set the `FCM_SERVICE_ACCOUNT` secret.

Database tests run on a throwaway local Postgres: `supabase/tests/run_local.sh`.

## Build

- Member app: `scripts/build_app.sh demo` (sample data, sign-in code 123456) or `scripts/build_app.sh prod` with `SUPABASE_URL` and `SUPABASE_ANON_KEY` set. See [`app/README.md`](app/README.md).
- Back-office: see [`admin/README.md`](admin/README.md). On Vercel, set the root directory to `admin` and add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
