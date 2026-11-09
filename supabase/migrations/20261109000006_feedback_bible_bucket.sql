-- Pilot feedback from members and staff, plus the public bucket that serves
-- the offline Bible files (<CODE>.json, built by scripts/build_bible_json.mjs).

create type public.feedback_kind as enum ('bug', 'idea', 'other');
create type public.feedback_status as enum ('new', 'planned', 'done', 'wontfix');

create table public.feedback (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid references public.churches (id) on delete set null,
  user_id     uuid references auth.users (id) on delete set null,
  kind        public.feedback_kind not null default 'idea',
  message     text not null check (length(trim(message)) between 3 and 4000),
  screen      text,                 -- where in the app it was sent from
  app_version text,
  platform    text,                 -- android / ios / web / admin
  status      public.feedback_status not null default 'new',
  created_at  timestamptz not null default now()
);
create index feedback_church_idx on public.feedback (church_id, created_at desc);
alter table public.feedback enable row level security;

-- Anyone signed in can send feedback (as themselves).
create policy feedback_insert on public.feedback for insert to authenticated
  with check (user_id = auth.uid());
-- Authors see their own; church admins see their church's; platform admins see all.
create policy feedback_select on public.feedback for select using (
  user_id = auth.uid()
  or (church_id is not null and public.is_church_admin(church_id))
  or public.is_platform_admin()
);
create policy feedback_update on public.feedback for update
  using (public.is_platform_admin()) with check (public.is_platform_admin());
grant select, insert, update on public.feedback to authenticated;

insert into storage.buckets (id, name, public)
values ('bible', 'bible', true)
on conflict (id) do nothing;
create policy bible_read on storage.objects for select using (bucket_id = 'bible');
