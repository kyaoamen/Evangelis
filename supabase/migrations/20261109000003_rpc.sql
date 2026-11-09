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
