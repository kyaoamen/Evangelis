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
