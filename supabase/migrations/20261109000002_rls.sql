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
