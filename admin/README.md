# Evangelis — church back-office (web)

Next.js (App Router) app for church staff: church page & branding, members and
invite codes, events and registrations, announcements (+ push), QR check-in,
pilot feedback, church verification documents, and a platform-admin review area.
UI in French first, with an EN toggle. All data rules live in Postgres RLS
(`../supabase/migrations`); the app only uses the public anon key.

## Configure

```bash
cp .env.example .env.local   # then fill in the two values
```

| Variable | Where to find it |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase → Project Settings → API → Project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase → Project Settings → API → anon / publishable key |

Without them every page redirects to `/setup`, which explains these steps.

In Supabase → Authentication → Email templates, make the "Magic Link" template
show `{{ .Token }}` so people receive a 6-digit code (sign-in is by code).
Set Authentication → URL configuration → Site URL to the deployed URL.

## Run

```bash
npm install
npm run dev          # http://localhost:3000
npm run lint
npm run build && npm start
```

## Deploy (Vercel)

1. Import the repository in Vercel and set **Root Directory** to `admin`.
2. Add the two environment variables above (Production + Preview).
3. Deploy. Add the Vercel URL as Site URL / redirect URL in Supabase Auth.

## Roles

- **owner / admin**: everything for their church (branding, members, roles,
  invites, verification documents, feedback).
- **pastor / editor**: events, announcements, check-in.
- **platform admin** (row in `platform_admins`): `/admin` — review queue for new
  churches (documents via signed URLs, accept/reject each, approve/reject the
  church) and triage of all feedback. Add one with SQL:
  `insert into platform_admins (user_id) select id from auth.users where email = 'you@example.com';`

## Notes

- Uploads: images go to the public `church-media` bucket under `<church_id>/`;
  verification documents go to the private `church-documents` bucket.
- Push: after publishing an announcement the app calls the
  `send-announcement-push` Edge Function. If FCM is not configured the
  announcement is still published and a note is shown. Scheduled announcements
  (future publish time) are not pushed automatically yet — that needs a cron
  job calling the same function.
- `scripts/mock-supabase.mjs` is a tiny fake API used only to screenshot the
  signed-in pages without a real project.
