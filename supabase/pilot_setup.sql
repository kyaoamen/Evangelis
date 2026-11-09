-- Evangelis: full database setup for a new Supabase project.
-- Paste into Supabase > SQL Editor > New query, then Run. Run it once, on an empty project.

-- ======== 20261109000001_core_schema.sql ========
-- Core schema for the multi-church platform (MVP).
-- Every church-owned table carries church_id; RLS (next migration) isolates tenants.
-- Translatable text is jsonb keyed by locale: {"fr": "...", "en": "..."}.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.church_status     as enum ('pending', 'active', 'suspended');
create type public.join_mode         as enum ('open', 'approval', 'invite');
create type public.member_role       as enum ('owner', 'admin', 'pastor', 'editor', 'member');
create type public.membership_status as enum ('pending', 'active', 'suspended', 'left');
create type public.visibility        as enum ('public', 'members');
create type public.registration_status as enum ('confirmed', 'waitlist', 'cancelled');
create type public.announcement_audience as enum ('all', 'members');

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create or replace function public.is_i18n_text(v jsonb) returns boolean
language sql immutable as $$
  select v is not null
     and jsonb_typeof(v) = 'object'
     and v <> '{}'::jsonb
     and not exists (
       select 1 from jsonb_each(v) e
       where e.key not in ('fr', 'en') or jsonb_typeof(e.value) <> 'string'
     )
$$;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text,
  first_name  text,
  last_name   text,
  phone       text,
  avatar_url  text,
  locale      text not null default 'fr' check (locale in ('fr', 'en')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create table public.platform_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- New auth user -> profile row.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, first_name, last_name, locale)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'first_name',
    new.raw_user_meta_data ->> 'last_name',
    coalesce(nullif(new.raw_user_meta_data ->> 'locale', ''), 'fr')
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Tenants
-- ---------------------------------------------------------------------------
create table public.churches (
  id             uuid primary key default gen_random_uuid(),
  slug           text not null unique check (slug ~ '^[a-z0-9](?:[a-z0-9-]{1,38})[a-z0-9]$'),
  name           text not null check (length(trim(name)) between 2 and 120),
  city           text,
  country        text,          -- ISO 3166-1 alpha-2
  timezone       text not null default 'Europe/Paris',
  default_locale text not null default 'fr' check (default_locale in ('fr', 'en')),
  join_mode      public.join_mode not null default 'approval',
  status         public.church_status not null default 'pending',
  created_by     uuid references auth.users (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index churches_name_idx on public.churches (lower(name));
create index churches_city_idx on public.churches (lower(city));
create trigger churches_updated_at before update on public.churches
  for each row execute function public.set_updated_at();

create table public.church_branding (
  church_id          uuid primary key references public.churches (id) on delete cascade,
  logo_url           text,
  cover_url          text,
  primary_color      text not null default '#0F3D3E' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  accent_color       text not null default '#D4A72C' check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  tagline            jsonb check (tagline is null or public.is_i18n_text(tagline)),
  welcome_text       jsonb check (welcome_text is null or public.is_i18n_text(welcome_text)),
  about_text         jsonb check (about_text is null or public.is_i18n_text(about_text)),
  featured_video_url text,
  address            text,
  phone              text,
  email              text,
  website            text,
  socials            jsonb not null default '{}'::jsonb,  -- {"youtube": url, "facebook": url, ...}
  updated_at         timestamptz not null default now()
);
create trigger church_branding_updated_at before update on public.church_branding
  for each row execute function public.set_updated_at();

create table public.memberships (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        public.member_role not null default 'member',
  status      public.membership_status not null default 'pending',
  consent_at  timestamptz,     -- GDPR art. 9 explicit consent
  joined_at   timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (church_id, user_id)
);
create index memberships_user_idx on public.memberships (user_id);
create trigger memberships_updated_at before update on public.memberships
  for each row execute function public.set_updated_at();

create table public.invites (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references public.churches (id) on delete cascade,
  code        text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  role        public.member_role not null default 'member' check (role <> 'owner'),
  max_uses    int check (max_uses is null or max_uses > 0),
  uses        int not null default 0,
  expires_at  timestamptz,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Content
-- ---------------------------------------------------------------------------
create table public.event_categories (
  id         uuid primary key default gen_random_uuid(),
  church_id  uuid not null references public.churches (id) on delete cascade,
  name       jsonb not null check (public.is_i18n_text(name)),
  sort       int not null default 0,
  created_at timestamptz not null default now()
);
create index event_categories_church_idx on public.event_categories (church_id, sort);

create table public.events (
  id                uuid primary key default gen_random_uuid(),
  church_id         uuid not null references public.churches (id) on delete cascade,
  category_id       uuid references public.event_categories (id) on delete set null,
  title             jsonb not null check (public.is_i18n_text(title)),
  description       jsonb check (description is null or public.is_i18n_text(description)),
  poster_url        text,
  starts_at         timestamptz not null,
  ends_at           timestamptz,
  location          text,
  capacity          int check (capacity is null or capacity > 0),
  max_seats_per_registration int not null default 1 check (max_seats_per_registration between 1 and 20),
  registration_open boolean not null default false,
  visibility        public.visibility not null default 'public',
  published_at      timestamptz,
  created_by        uuid references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);
create index events_church_start_idx on public.events (church_id, starts_at);
create trigger events_updated_at before update on public.events
  for each row execute function public.set_updated_at();

create table public.event_registrations (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events (id) on delete cascade,
  church_id     uuid not null references public.churches (id) on delete cascade,
  user_id       uuid not null references auth.users (id) on delete cascade,
  status        public.registration_status not null,
  seats         int not null default 1 check (seats between 1 and 20),
  answers       jsonb not null default '{}'::jsonb,
  qr_token      text not null unique default replace(gen_random_uuid()::text, '-', ''),
  checked_in_at timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
-- One live registration per person per event.
create unique index event_registrations_one_live
  on public.event_registrations (event_id, user_id) where status <> 'cancelled';
create index event_registrations_user_idx on public.event_registrations (user_id);
create trigger event_registrations_updated_at before update on public.event_registrations
  for each row execute function public.set_updated_at();

create table public.announcements (
  id           uuid primary key default gen_random_uuid(),
  church_id    uuid not null references public.churches (id) on delete cascade,
  title        jsonb not null check (public.is_i18n_text(title)),
  body         jsonb not null check (public.is_i18n_text(body)),
  image_url    text,
  audience     public.announcement_audience not null default 'all',
  publish_at   timestamptz not null default now(),
  push_sent_at timestamptz,
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index announcements_church_pub_idx on public.announcements (church_id, publish_at desc);
create trigger announcements_updated_at before update on public.announcements
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Bible (shared reference data) and verse of the day
-- ---------------------------------------------------------------------------
create table public.bible_translations (
  code     text primary key,          -- 'LSG1910', 'KJV'
  name     text not null,
  locale   text not null check (locale in ('fr', 'en')),
  license  text not null              -- 'public-domain' or licence reference
);

create table public.bible_books (
  translation text not null references public.bible_translations (code) on delete cascade,
  book        smallint not null check (book between 1 and 66),   -- canonical order
  name        text not null,
  abbrev      text not null,
  chapters    smallint not null,
  primary key (translation, book)
);

create table public.bible_verses (
  translation text not null references public.bible_translations (code) on delete cascade,
  book        smallint not null,
  chapter     smallint not null,
  verse       smallint not null,
  text        text not null,
  primary key (translation, book, chapter, verse)
);

create table public.verses_of_day (
  id         uuid primary key default gen_random_uuid(),
  church_id  uuid references public.churches (id) on delete cascade,  -- null = platform default
  day        date not null,
  book       smallint not null,
  chapter    smallint not null,
  verse_from smallint not null,
  verse_to   smallint not null,
  created_at timestamptz not null default now(),
  check (verse_to >= verse_from)
);
create unique index verses_of_day_church_day on public.verses_of_day (coalesce(church_id, '00000000-0000-0000-0000-000000000000'::uuid), day);

-- ---------------------------------------------------------------------------
-- Devices (push)
-- ---------------------------------------------------------------------------
create table public.device_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  token        text not null unique,
  platform     text not null check (platform in ('ios', 'android', 'web')),
  locale       text not null default 'fr' check (locale in ('fr', 'en')),
  last_seen_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

-- ---------------------------------------------------------------------------
-- Audit
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id            bigint generated always as identity primary key,
  church_id     uuid references public.churches (id) on delete cascade,
  actor_user_id uuid references auth.users (id) on delete set null,
  action        text not null,
  entity        text not null,
  entity_id     uuid,
  details       jsonb not null default '{}'::jsonb,
  at            timestamptz not null default now()
);
create index audit_log_church_idx on public.audit_log (church_id, at desc);

-- ======== 20261109000002_rls.sql ========
-- Row-level security: the database, not the app, decides which church sees what.

-- ---------------------------------------------------------------------------
-- Role helpers (security definer so they can read memberships under RLS)
-- ---------------------------------------------------------------------------
create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
$$;

create or replace function public.is_member(p_church uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.memberships
    where church_id = p_church and user_id = auth.uid() and status = 'active'
  )
$$;

create or replace function public.has_role(p_church uuid, p_roles public.member_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.memberships
    where church_id = p_church and user_id = auth.uid()
      and status = 'active' and role = any (p_roles)
  )
$$;

-- Staff = anyone who edits content.
create or replace function public.is_staff(p_church uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.has_role(p_church, array['owner','admin','pastor','editor']::public.member_role[])
$$;

create or replace function public.is_church_admin(p_church uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.has_role(p_church, array['owner','admin']::public.member_role[])
$$;

-- Any membership row (even pending) — lets applicants see their pending church.
create or replace function public.has_membership(p_church uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.memberships where church_id = p_church and user_id = auth.uid())
$$;

create or replace function public.church_is_active(p_church uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.churches where id = p_church and status = 'active')
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------
alter table public.profiles            enable row level security;
alter table public.platform_admins     enable row level security;
alter table public.churches            enable row level security;
alter table public.church_branding     enable row level security;
alter table public.memberships         enable row level security;
alter table public.invites             enable row level security;
alter table public.event_categories    enable row level security;
alter table public.events              enable row level security;
alter table public.event_registrations enable row level security;
alter table public.announcements       enable row level security;
alter table public.bible_translations  enable row level security;
alter table public.bible_books         enable row level security;
alter table public.bible_verses        enable row level security;
alter table public.verses_of_day       enable row level security;
alter table public.device_tokens       enable row level security;
alter table public.audit_log           enable row level security;

-- ---------------------------------------------------------------------------
-- profiles: yourself; staff see members of their church; platform admins all
-- ---------------------------------------------------------------------------
create policy profiles_select on public.profiles for select using (
  id = auth.uid()
  or public.is_platform_admin()
  or exists (
    select 1 from public.memberships them
    where them.user_id = profiles.id and public.is_staff(them.church_id)
  )
);
create policy profiles_update on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- platform_admins: you can see whether you are one
-- ---------------------------------------------------------------------------
create policy platform_admins_select on public.platform_admins for select
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- churches: active ones are public; members and platform admins see their own
-- Creation goes through create_church(); status changes through approve_church().
-- ---------------------------------------------------------------------------
create policy churches_select on public.churches for select using (
  status = 'active'
  or public.is_platform_admin()
  or public.has_membership(id)
);
create policy churches_update on public.churches for update
  using (public.is_church_admin(id) or public.is_platform_admin())
  with check (public.is_church_admin(id) or public.is_platform_admin());

-- Only platform admins may change status, slug or creator.
create or replace function public.guard_church_update() returns trigger
language plpgsql as $$
begin
  if (new.status is distinct from old.status
      or new.slug is distinct from old.slug
      or new.created_by is distinct from old.created_by)
     and not public.is_platform_admin()
     and current_user not in ('postgres', 'service_role', 'supabase_admin') then
    raise exception 'only platform admins can change status, slug or owner' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger churches_guard before update on public.churches
  for each row execute function public.guard_church_update();

-- ---------------------------------------------------------------------------
-- church_branding
-- ---------------------------------------------------------------------------
create policy branding_select on public.church_branding for select using (
  public.church_is_active(church_id) or public.is_member(church_id)
  or public.is_church_admin(church_id) or public.is_platform_admin()
);
create policy branding_update on public.church_branding for update
  using (public.is_church_admin(church_id)) with check (public.is_church_admin(church_id));

-- ---------------------------------------------------------------------------
-- memberships: own rows + church admins/staff. Writes go through RPCs.
-- ---------------------------------------------------------------------------
create policy memberships_select on public.memberships for select using (
  user_id = auth.uid() or public.is_staff(church_id) or public.is_platform_admin()
);

-- ---------------------------------------------------------------------------
-- invites: church admins only
-- ---------------------------------------------------------------------------
create policy invites_all on public.invites for all
  using (public.is_church_admin(church_id))
  with check (public.is_church_admin(church_id));

-- ---------------------------------------------------------------------------
-- event_categories
-- ---------------------------------------------------------------------------
create policy event_categories_select on public.event_categories for select using (
  public.church_is_active(church_id) or public.is_member(church_id)
);
create policy event_categories_write on public.event_categories for all
  using (public.is_staff(church_id)) with check (public.is_staff(church_id));

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
create policy events_select on public.events for select using (
  public.is_staff(church_id)
  or (
    published_at is not null and published_at <= now()
    and public.church_is_active(church_id)
    and (visibility = 'public' or public.is_member(church_id))
  )
);
create policy events_insert on public.events for insert
  with check (public.is_staff(church_id));
create policy events_update on public.events for update
  using (public.is_staff(church_id)) with check (public.is_staff(church_id));
create policy events_delete on public.events for delete
  using (public.is_staff(church_id));

-- ---------------------------------------------------------------------------
-- event_registrations: own rows + staff. Writes go through RPCs.
-- ---------------------------------------------------------------------------
create policy event_registrations_select on public.event_registrations for select using (
  user_id = auth.uid() or public.is_staff(church_id)
);

-- ---------------------------------------------------------------------------
-- announcements
-- ---------------------------------------------------------------------------
create policy announcements_select on public.announcements for select using (
  public.is_staff(church_id)
  or (
    publish_at <= now()
    and public.church_is_active(church_id)
    and (audience = 'all' or public.is_member(church_id))
  )
);
create policy announcements_insert on public.announcements for insert
  with check (public.is_staff(church_id));
create policy announcements_update on public.announcements for update
  using (public.is_staff(church_id)) with check (public.is_staff(church_id));
create policy announcements_delete on public.announcements for delete
  using (public.is_staff(church_id));

-- ---------------------------------------------------------------------------
-- Bible: readable by everyone; written only by migrations / service role
-- ---------------------------------------------------------------------------
create policy bible_translations_select on public.bible_translations for select using (true);
create policy bible_books_select        on public.bible_books        for select using (true);
create policy bible_verses_select       on public.bible_verses       for select using (true);

create policy verses_of_day_select on public.verses_of_day for select using (
  church_id is null or public.church_is_active(church_id) or public.is_member(church_id)
);
create policy verses_of_day_write on public.verses_of_day for all
  using (church_id is not null and public.is_staff(church_id))
  with check (church_id is not null and public.is_staff(church_id));

-- ---------------------------------------------------------------------------
-- device_tokens: your own only
-- ---------------------------------------------------------------------------
create policy device_tokens_own on public.device_tokens for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- audit_log: church admins read their church's log; inserts via definer RPCs
-- ---------------------------------------------------------------------------
create policy audit_log_select on public.audit_log for select using (
  (church_id is not null and public.is_church_admin(church_id)) or public.is_platform_admin()
);

-- ---------------------------------------------------------------------------
-- Grants (Supabase grants these by default; explicit for clarity)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select on public.churches, public.church_branding, public.event_categories,
  public.events, public.announcements, public.bible_translations, public.bible_books,
  public.bible_verses, public.verses_of_day to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to anon, authenticated;

-- ======== 20261109000003_rpc.sql ========
-- RPC functions for writes that span several rows or need checks RLS can't express.
-- All are security definer and check the caller explicitly.

create or replace function public.require_uid() returns uuid
language plpgsql stable as $$
declare v uuid := auth.uid();
begin
  if v is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  return v;
end $$;

create or replace function public.log_action(p_church uuid, p_action text, p_entity text, p_entity_id uuid, p_details jsonb default '{}'::jsonb)
returns void language sql security definer set search_path = public as $$
  insert into public.audit_log (church_id, actor_user_id, action, entity, entity_id, details)
  values (p_church, auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_details, '{}'::jsonb));
$$;
revoke execute on function public.log_action(uuid, text, text, uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Churches
-- ---------------------------------------------------------------------------
create or replace function public.create_church(
  p_name text, p_slug text, p_city text default null, p_country text default null,
  p_default_locale text default 'fr', p_timezone text default 'Europe/Paris'
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := public.require_uid();
  v_id  uuid;
begin
  insert into public.churches (name, slug, city, country, default_locale, timezone, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_city, upper(p_country), p_default_locale, p_timezone, v_uid)
  returning id into v_id;

  insert into public.church_branding (church_id) values (v_id);

  insert into public.memberships (church_id, user_id, role, status, consent_at, joined_at)
  values (v_id, v_uid, 'owner', 'active', now(), now());

  perform public.log_action(v_id, 'church.create', 'church', v_id);
  return v_id;
exception when unique_violation then
  raise exception 'slug already taken' using errcode = '23505';
end $$;

create or replace function public.set_church_status(p_church uuid, p_status public.church_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'platform admin only' using errcode = '42501';
  end if;
  update public.churches set status = p_status where id = p_church;
  if not found then raise exception 'church not found' using errcode = 'P0002'; end if;
  perform public.log_action(p_church, 'church.status', 'church', p_church, jsonb_build_object('status', p_status));
end $$;

-- Search active churches by name or city (visitor-safe).
create or replace function public.search_churches(p_query text, p_limit int default 20)
returns table (id uuid, slug text, name text, city text, country text, logo_url text, primary_color text)
language sql stable security definer set search_path = public as $$
  select c.id, c.slug, c.name, c.city, c.country, b.logo_url, b.primary_color
  from public.churches c
  left join public.church_branding b on b.church_id = c.id
  where c.status = 'active'
    and (coalesce(trim(p_query), '') = ''
         or c.name ilike '%' || trim(p_query) || '%'
         or c.city ilike '%' || trim(p_query) || '%'
         or c.slug = lower(trim(p_query)))
  order by c.name
  limit least(greatest(p_limit, 1), 50)
$$;

-- ---------------------------------------------------------------------------
-- Memberships
-- ---------------------------------------------------------------------------
create or replace function public.join_church(p_church uuid, p_consent boolean, p_invite_code text default null)
returns public.memberships
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := public.require_uid();
  v_church public.churches;
  v_invite public.invites;
  v_row    public.memberships;
  v_status public.membership_status;
  v_role   public.member_role := 'member';
begin
  if p_consent is not true then
    raise exception 'consent required' using errcode = '22023';
  end if;

  select * into v_church from public.churches where id = p_church and status = 'active';
  if not found then raise exception 'church not found' using errcode = 'P0002'; end if;

  select * into v_row from public.memberships where church_id = p_church and user_id = v_uid for update;
  if found and v_row.status in ('active', 'pending') then
    return v_row;
  end if;
  if found and v_row.status = 'suspended' then
    raise exception 'membership suspended' using errcode = '42501';
  end if;

  if p_invite_code is not null and length(trim(p_invite_code)) > 0 then
    select * into v_invite from public.invites
     where church_id = p_church and code = upper(trim(p_invite_code))
       and (expires_at is null or expires_at > now())
       and (max_uses is null or uses < max_uses)
     for update;
    if not found then raise exception 'invalid invite code' using errcode = '22023'; end if;
    update public.invites set uses = uses + 1 where id = v_invite.id;
    v_status := 'active';
    v_role := v_invite.role;
  elsif v_church.join_mode = 'open' then
    v_status := 'active';
  elsif v_church.join_mode = 'approval' then
    v_status := 'pending';
  else
    raise exception 'invite code required' using errcode = '22023';
  end if;

  insert into public.memberships (church_id, user_id, role, status, consent_at, joined_at)
  values (p_church, v_uid, v_role, v_status, now(), case when v_status = 'active' then now() end)
  on conflict (church_id, user_id) do update
    set role = excluded.role, status = excluded.status,
        consent_at = excluded.consent_at, joined_at = excluded.joined_at
  returning * into v_row;

  return v_row;
end $$;

create or replace function public.leave_church(p_church uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := public.require_uid();
  v_role public.member_role;
begin
  select role into v_role from public.memberships where church_id = p_church and user_id = v_uid;
  if v_role = 'owner' and (select count(*) from public.memberships
                            where church_id = p_church and role = 'owner' and status = 'active') <= 1 then
    raise exception 'the last owner cannot leave' using errcode = '42501';
  end if;
  update public.memberships set status = 'left', role = 'member'
   where church_id = p_church and user_id = v_uid;
end $$;

-- Approve / reject / suspend / reinstate a member (church admins).
create or replace function public.set_membership_status(p_membership uuid, p_status public.membership_status)
returns public.memberships
language plpgsql security definer set search_path = public as $$
declare v_row public.memberships;
begin
  select * into v_row from public.memberships where id = p_membership for update;
  if not found or not public.is_church_admin(v_row.church_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_row.role = 'owner' then
    raise exception 'owners cannot be suspended' using errcode = '42501';
  end if;
  update public.memberships
     set status = p_status,
         joined_at = case when p_status = 'active' then coalesce(joined_at, now()) else joined_at end
   where id = p_membership
  returning * into v_row;
  perform public.log_action(v_row.church_id, 'membership.status', 'membership', v_row.id, jsonb_build_object('status', p_status));
  return v_row;
end $$;

-- Change a member's role. Owners can grant admin; admins can grant pastor/editor/member.
create or replace function public.set_member_role(p_membership uuid, p_role public.member_role)
returns public.memberships
language plpgsql security definer set search_path = public as $$
declare v_row public.memberships;
begin
  select * into v_row from public.memberships where id = p_membership for update;
  if not found or not public.is_church_admin(v_row.church_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_role = 'owner' or v_row.role = 'owner' then
    raise exception 'ownership transfer is not supported here' using errcode = '42501';
  end if;
  if (p_role = 'admin' or v_row.role = 'admin')
     and not public.has_role(v_row.church_id, array['owner']::public.member_role[]) then
    raise exception 'only owners manage admins' using errcode = '42501';
  end if;
  update public.memberships set role = p_role where id = p_membership returning * into v_row;
  perform public.log_action(v_row.church_id, 'membership.role', 'membership', v_row.id, jsonb_build_object('role', p_role));
  return v_row;
end $$;

-- ---------------------------------------------------------------------------
-- Event registrations
-- ---------------------------------------------------------------------------
create or replace function public.register_for_event(p_event uuid, p_seats int default 1, p_answers jsonb default '{}'::jsonb)
returns public.event_registrations
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := public.require_uid();
  v_event public.events;
  v_taken int;
  v_row   public.event_registrations;
begin
  -- Lock the event row so concurrent registrations can't oversell seats.
  select * into v_event from public.events where id = p_event for update;
  if not found
     or v_event.published_at is null or v_event.published_at > now()
     or not public.church_is_active(v_event.church_id) then
    raise exception 'event not found' using errcode = 'P0002';
  end if;
  if not public.is_member(v_event.church_id) then
    raise exception 'members only' using errcode = '42501';
  end if;
  if not v_event.registration_open or v_event.starts_at <= now() then
    raise exception 'registration closed' using errcode = '22023';
  end if;
  if p_seats is null or p_seats < 1 or p_seats > v_event.max_seats_per_registration then
    raise exception 'invalid number of seats' using errcode = '22023';
  end if;

  select * into v_row from public.event_registrations
   where event_id = p_event and user_id = v_uid and status <> 'cancelled';
  if found then return v_row; end if;

  select coalesce(sum(seats), 0) into v_taken from public.event_registrations
   where event_id = p_event and status = 'confirmed';

  insert into public.event_registrations (event_id, church_id, user_id, status, seats, answers)
  values (
    p_event, v_event.church_id, v_uid,
    case when v_event.capacity is null or v_taken + p_seats <= v_event.capacity
         then 'confirmed'::public.registration_status else 'waitlist'::public.registration_status end,
    p_seats, coalesce(p_answers, '{}'::jsonb)
  )
  returning * into v_row;
  return v_row;
end $$;

-- Promote waitlisted registrations (oldest first) while seats remain.
create or replace function public.promote_waitlist(p_event uuid)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_capacity int;
  v_taken int;
  v_promoted int := 0;
  r record;
begin
  select capacity into v_capacity from public.events where id = p_event for update;
  select coalesce(sum(seats), 0) into v_taken from public.event_registrations
   where event_id = p_event and status = 'confirmed';
  for r in select id, seats from public.event_registrations
            where event_id = p_event and status = 'waitlist' order by created_at, id
  loop
    exit when v_capacity is not null and v_taken + r.seats > v_capacity;
    update public.event_registrations set status = 'confirmed' where id = r.id;
    v_taken := v_taken + r.seats;
    v_promoted := v_promoted + 1;
  end loop;
  return v_promoted;
end $$;
revoke execute on function public.promote_waitlist(uuid) from public, anon, authenticated;

create or replace function public.cancel_registration(p_registration uuid)
returns public.event_registrations
language plpgsql security definer set search_path = public as $$
declare v_row public.event_registrations;
begin
  select * into v_row from public.event_registrations where id = p_registration for update;
  if not found or (v_row.user_id is distinct from auth.uid() and not public.is_staff(v_row.church_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_row.status = 'cancelled' then return v_row; end if;
  update public.event_registrations set status = 'cancelled' where id = p_registration returning * into v_row;
  perform public.promote_waitlist(v_row.event_id);
  return v_row;
end $$;

-- Door check-in by QR token (staff of the event's church).
create or replace function public.check_in(p_qr_token text)
returns table (registration_id uuid, event_id uuid, status public.registration_status, seats int,
               first_name text, last_name text, already_checked_in boolean)
language plpgsql security definer set search_path = public as $$
declare v_row public.event_registrations; v_already boolean;
begin
  select * into v_row from public.event_registrations where qr_token = p_qr_token for update;
  if not found or not public.is_staff(v_row.church_id) then
    raise exception 'registration not found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'confirmed' then
    raise exception 'registration is %', v_row.status using errcode = '22023';
  end if;
  v_already := v_row.checked_in_at is not null;
  if not v_already then
    update public.event_registrations set checked_in_at = now() where id = v_row.id;
  end if;
  return query
    select v_row.id, v_row.event_id, v_row.status, v_row.seats, p.first_name, p.last_name, v_already
    from public.profiles p where p.id = v_row.user_id;
end $$;

-- Seats summary visible to anyone who can see the event.
create or replace function public.event_seats(p_event uuid)
returns table (capacity int, confirmed_seats int, waitlist_count int)
language sql stable security definer set search_path = public as $$
  select e.capacity,
         coalesce((select sum(seats) from public.event_registrations r where r.event_id = e.id and r.status = 'confirmed'), 0)::int,
         (select count(*) from public.event_registrations r where r.event_id = e.id and r.status = 'waitlist')::int
  from public.events e
  where e.id = p_event
    and (public.is_staff(e.church_id)
         or (e.published_at <= now() and public.church_is_active(e.church_id)
             and (e.visibility = 'public' or public.is_member(e.church_id))))
$$;

-- ---------------------------------------------------------------------------
-- Verse of the day: the church's pick, else the platform default, else a
-- deterministic rotation through a built-in list.
-- ---------------------------------------------------------------------------
create or replace function public.verse_of_day(p_church uuid, p_translation text default 'LSG1910', p_day date default current_date)
returns table (reference text, text text, translation text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_book smallint; v_ch smallint; v_from smallint; v_to smallint;
  v_rot  int[][] := array[
    [43,3,16,16],[19,23,1,1],[50,4,13,13],[45,8,28,28],[20,3,5,6],
    [23,41,10,10],[24,29,11,11],[40,11,28,28],[61,3,9,9],[19,46,1,1],
    [46,13,4,4],[58,11,1,1],[47,5,17,17],[62,4,8,8]
  ];
  v_i int;
begin
  select book, chapter, verse_from, verse_to into v_book, v_ch, v_from, v_to
    from public.verses_of_day
   where day = p_day and (church_id = p_church or church_id is null)
   order by church_id nulls last limit 1;
  if not found then
    v_i := (p_day - date '2026-01-01') % array_length(v_rot, 1);
    if v_i < 0 then v_i := v_i + array_length(v_rot, 1); end if;
    v_i := v_i + 1;
    v_book := v_rot[v_i][1]; v_ch := v_rot[v_i][2]; v_from := v_rot[v_i][3]; v_to := v_rot[v_i][4];
  end if;

  return query
    select bb.name || ' ' || v_ch || ':' || v_from || case when v_to > v_from then '-' || v_to else '' end,
           string_agg(v.text, ' ' order by v.verse),
           p_translation
      from public.bible_books bb
      join public.bible_verses v on v.translation = bb.translation and v.book = bb.book
     where bb.translation = p_translation and bb.book = v_book
       and v.chapter = v_ch and v.verse between v_from and v_to
     group by bb.name;
end $$;

-- ---------------------------------------------------------------------------
-- Push devices
-- ---------------------------------------------------------------------------
create or replace function public.register_device(p_token text, p_platform text, p_locale text default 'fr')
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := public.require_uid();
begin
  insert into public.device_tokens (user_id, token, platform, locale)
  values (v_uid, p_token, p_platform, p_locale)
  on conflict (token) do update
    set user_id = v_uid, platform = excluded.platform, locale = excluded.locale, last_seen_at = now();
end $$;

-- ---------------------------------------------------------------------------
-- GDPR: export my data, delete my account data
-- ---------------------------------------------------------------------------
create or replace function public.export_my_data()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'profile', (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'memberships', coalesce((select jsonb_agg(jsonb_build_object(
        'church', c.name, 'role', m.role, 'status', m.status,
        'consent_at', m.consent_at, 'joined_at', m.joined_at))
      from public.memberships m join public.churches c on c.id = m.church_id
      where m.user_id = auth.uid()), '[]'::jsonb),
    'event_registrations', coalesce((select jsonb_agg(jsonb_build_object(
        'event', e.title, 'starts_at', e.starts_at, 'status', r.status, 'seats', r.seats,
        'answers', r.answers, 'created_at', r.created_at))
      from public.event_registrations r join public.events e on e.id = r.event_id
      where r.user_id = auth.uid()), '[]'::jsonb),
    'exported_at', now()
  )
$$;

-- Removes the caller's data; the auth user itself is deleted by the
-- delete-account Edge Function with the service role (cascades everything).
create or replace function public.delete_my_data()
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := public.require_uid();
begin
  if exists (select 1 from public.memberships m
              where m.user_id = v_uid and m.role = 'owner' and m.status = 'active'
                and (select count(*) from public.memberships o
                      where o.church_id = m.church_id and o.role = 'owner' and o.status = 'active') = 1) then
    raise exception 'transfer ownership of your church before deleting your account' using errcode = '42501';
  end if;
  delete from public.event_registrations where user_id = v_uid;
  delete from public.device_tokens where user_id = v_uid;
  delete from public.memberships where user_id = v_uid;
  update public.profiles set first_name = null, last_name = null, phone = null, avatar_url = null where id = v_uid;
end $$;

-- Lock down: anonymous visitors may only call read-only helpers.
revoke execute on all functions in schema public from anon;
grant execute on function public.search_churches(text, int) to anon;
grant execute on function public.verse_of_day(uuid, text, date) to anon;
grant execute on function public.event_seats(uuid) to anon;
grant execute on function public.is_member(uuid), public.is_staff(uuid), public.is_church_admin(uuid),
  public.has_role(uuid, public.member_role[]), public.church_is_active(uuid), public.has_membership(uuid),
  public.is_platform_admin(), public.is_i18n_text(jsonb) to anon;

-- ======== 20261109000004_storage.sql ========
-- Media bucket. Objects live under <church_id>/<anything>; policies mirror RLS.
insert into storage.buckets (id, name, public)
values ('church-media', 'church-media', true)
on conflict (id) do nothing;

create policy church_media_read on storage.objects for select
  using (bucket_id = 'church-media');

create policy church_media_insert on storage.objects for insert
  with check (
    bucket_id = 'church-media'
    and public.is_staff(((storage.foldername(name))[1])::uuid)
  );

create policy church_media_update on storage.objects for update
  using (bucket_id = 'church-media' and public.is_staff(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'church-media' and public.is_staff(((storage.foldername(name))[1])::uuid));

create policy church_media_delete on storage.objects for delete
  using (bucket_id = 'church-media' and public.is_staff(((storage.foldername(name))[1])::uuid));

-- ======== 20261109000005_church_verification.sql ========
-- Church verification: a new church uploads 5 documents; a platform admin
-- reviews them before the church goes live.

create type public.church_document_type as enum (
  'registration_receipt',   -- Récépissé d'enregistrement
  'founding_minutes',       -- Procès-verbal d'AG constitutive
  'church_type',            -- Type d'église (statuts / déclaration)
  'leader_diploma',         -- Diplôme du responsable
  'leader_id'               -- Pièce d'identité du responsable
);
create type public.document_status as enum ('submitted', 'accepted', 'rejected');

alter table public.churches
  add column church_type text,                  -- e.g. 'baptiste', 'évangélique', 'pentecôtiste'
  add column review_note text,                  -- reason shown to the church when rejected
  add column submitted_for_review_at timestamptz,
  add column reviewed_at timestamptz,
  add column reviewed_by uuid references auth.users (id) on delete set null;

create table public.church_documents (
  id           uuid primary key default gen_random_uuid(),
  church_id    uuid not null references public.churches (id) on delete cascade,
  type         public.church_document_type not null,
  storage_path text not null,          -- church-documents/<church_id>/<file>
  file_name    text not null,
  status       public.document_status not null default 'submitted',
  review_note  text,
  uploaded_by  uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (church_id, type)
);
alter table public.church_documents enable row level security;

create policy church_documents_select on public.church_documents for select using (
  public.is_church_admin(church_id) or public.is_platform_admin()
);
-- Church admins add/replace documents while the church is not yet active.
create policy church_documents_write on public.church_documents for insert with check (
  public.is_church_admin(church_id) and not public.church_is_active(church_id)
);
create policy church_documents_replace on public.church_documents for update using (
  public.is_church_admin(church_id) and not public.church_is_active(church_id)
) with check (
  public.is_church_admin(church_id) and status = 'submitted'
);
create policy church_documents_delete on public.church_documents for delete using (
  public.is_church_admin(church_id) and not public.church_is_active(church_id)
);
grant select, insert, update, delete on public.church_documents to authenticated;

-- Extend the status guard: review columns are platform-admin only too.
create or replace function public.guard_church_update() returns trigger
language plpgsql as $$
begin
  if (new.status is distinct from old.status
      or new.slug is distinct from old.slug
      or new.created_by is distinct from old.created_by
      or new.review_note is distinct from old.review_note
      or new.reviewed_at is distinct from old.reviewed_at
      or new.reviewed_by is distinct from old.reviewed_by
      or new.submitted_for_review_at is distinct from old.submitted_for_review_at)
     and not public.is_platform_admin()
     -- security definer RPCs run as the owner (postgres) and pass
     and current_user not in ('postgres', 'service_role', 'supabase_admin') then
    raise exception 'only platform admins can change status, slug, owner or review fields' using errcode = '42501';
  end if;
  return new;
end $$;

-- Church admin submits for review once all 5 documents are uploaded.
create or replace function public.submit_church_for_review(p_church uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_missing text[];
begin
  if not public.is_church_admin(p_church) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select array_agg(t::text) into v_missing
    from unnest(enum_range(null::public.church_document_type)) t
   where not exists (select 1 from public.church_documents d
                      where d.church_id = p_church and d.type = t and d.status <> 'rejected');
  if v_missing is not null then
    raise exception 'missing documents: %', array_to_string(v_missing, ', ') using errcode = '22023';
  end if;
  update public.churches set submitted_for_review_at = now(), review_note = null
   where id = p_church and status = 'pending';
  perform public.log_action(p_church, 'church.submit_review', 'church', p_church);
end $$;

-- Platform admin decision. Rejection needs a note the church will see.
create or replace function public.review_church(p_church uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'platform admin only' using errcode = '42501';
  end if;
  if not p_approve and coalesce(trim(p_note), '') = '' then
    raise exception 'a rejection needs a note' using errcode = '22023';
  end if;
  update public.churches
     set status = case when p_approve then 'active'::public.church_status else 'pending'::public.church_status end,
         review_note = case when p_approve then null else p_note end,
         submitted_for_review_at = case when p_approve then submitted_for_review_at end,
         reviewed_at = now(), reviewed_by = auth.uid()
   where id = p_church;
  if not found then raise exception 'church not found' using errcode = 'P0002'; end if;
  if p_approve then
    update public.church_documents set status = 'accepted' where church_id = p_church;
  end if;
  perform public.log_action(p_church, case when p_approve then 'church.approve' else 'church.reject' end,
                            'church', p_church, jsonb_build_object('note', p_note));
end $$;

-- Per-document decision (e.g. a blurry ID).
create or replace function public.review_church_document(p_document uuid, p_accept boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'platform admin only' using errcode = '42501';
  end if;
  update public.church_documents
     set status = case when p_accept then 'accepted'::public.document_status else 'rejected'::public.document_status end,
         review_note = p_note
   where id = p_document;
  if not found then raise exception 'document not found' using errcode = 'P0002'; end if;
end $$;
revoke execute on function public.submit_church_for_review(uuid), public.review_church(uuid, boolean, text),
  public.review_church_document(uuid, boolean, text) from anon;

-- Private bucket for the documents (never public; signed URLs only).
insert into storage.buckets (id, name, public)
values ('church-documents', 'church-documents', false)
on conflict (id) do nothing;

create policy church_documents_obj_read on storage.objects for select using (
  bucket_id = 'church-documents'
  and (public.is_platform_admin() or public.is_church_admin(((storage.foldername(name))[1])::uuid))
);
create policy church_documents_obj_insert on storage.objects for insert with check (
  bucket_id = 'church-documents'
  and public.is_church_admin(((storage.foldername(name))[1])::uuid)
  and not public.church_is_active(((storage.foldername(name))[1])::uuid)
);
create policy church_documents_obj_delete on storage.objects for delete using (
  bucket_id = 'church-documents'
  and public.is_church_admin(((storage.foldername(name))[1])::uuid)
  and not public.church_is_active(((storage.foldername(name))[1])::uuid)
);

-- Platform-admin review queue.
create or replace view public.church_review_queue with (security_invoker = true) as
select c.id, c.name, c.slug, c.city, c.country, c.church_type, c.submitted_for_review_at,
       (select count(*) from public.church_documents d where d.church_id = c.id) as documents,
       p.first_name || ' ' || coalesce(p.last_name, '') as owner_name, p.email as owner_email
  from public.churches c
  left join public.profiles p on p.id = c.created_by
 where c.status = 'pending' and c.submitted_for_review_at is not null;
grant select on public.church_review_queue to authenticated;

-- ======== 20261109000006_feedback_bible_bucket.sql ========
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

-- ======== Bible reference data ========
insert into public.bible_translations (code, name, locale, license) values
  ('LSG1910', 'Louis Segond 1910', 'fr', 'public-domain'),
  ('KJV', 'King James Version', 'en', 'public-domain')
on conflict do nothing;
