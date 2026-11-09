-- Behaviour tests for tenancy, RLS and RPCs. Run with tests/run_local.sh.
\set ON_ERROR_STOP 1
\set QUIET 1

create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'FAIL: %', msg; end if;
  raise notice 'ok - %', msg;
end $$;
create function t.fails(stmt text, msg text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    raise notice 'ok - % (%)', msg, sqlerrm;
    return;
  end;
  raise exception 'FAIL: expected error: %', msg;
end $$;
grant execute on all functions in schema t to anon, authenticated;

-- Users
insert into auth.users (id, email, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-000000000001', 'owner@x.test', '{"first_name":"Olivia","last_name":"Owner"}'),
  ('a0000000-0000-0000-0000-000000000002', 'alice@x.test', '{"first_name":"Alice"}'),
  ('a0000000-0000-0000-0000-000000000003', 'bob@x.test',   '{"first_name":"Bob"}'),
  ('a0000000-0000-0000-0000-000000000004', 'carol@x.test', '{"first_name":"Carol","locale":"en"}'),
  ('a0000000-0000-0000-0000-000000000005', 'pa@x.test',    '{"first_name":"Platform"}'),
  ('a0000000-0000-0000-0000-000000000006', 'other@x.test', '{"first_name":"Other"}');
insert into public.platform_admins (user_id) values ('a0000000-0000-0000-0000-000000000005');

select t.ok((select count(*) from public.profiles) = 6, 'profiles created by auth trigger');
select t.ok((select locale from public.profiles where email = 'carol@x.test') = 'en', 'locale taken from signup metadata');

\set as_owner 'reset role; select set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', false); set role authenticated;'
\set as_alice 'reset role; select set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000002'', false); set role authenticated;'
\set as_bob   'reset role; select set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000003'', false); set role authenticated;'
\set as_carol 'reset role; select set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000004'', false); set role authenticated;'
\set as_pa    'reset role; select set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', false); set role authenticated;'
\set as_other 'reset role; select set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', false); set role authenticated;'
\set as_anon  'reset role; select set_config(''request.jwt.claim.sub'', '''', false); set role anon;'

-- ---------------------------------------------------------------- churches
:as_owner
select set_config('t.church', public.create_church('Vases Test', 'vases-test', 'Noisy-le-Grand', 'fr')::text, false);
select t.ok((select status from public.churches where id = current_setting('t.church')::uuid) = 'pending', 'new church starts pending');
select t.ok((select role from public.memberships where church_id = current_setting('t.church')::uuid) = 'owner', 'creator is owner');
select t.fails($$ select public.create_church('Dup', 'vases-test') $$, 'slug must be unique');
select t.fails($$ update public.churches set status = 'active' where slug = 'vases-test' $$, 'owner cannot self-approve');
select t.fails($$ select public.set_church_status(current_setting('t.church')::uuid, 'active') $$, 'set_church_status is platform-admin only');

:as_anon
select t.ok((select count(*) from public.churches where slug = 'vases-test') = 0, 'anon cannot see pending church');
:as_bob
select t.ok((select count(*) from public.churches where slug = 'vases-test') = 0, 'outsider cannot see pending church');

:as_pa
select public.set_church_status(current_setting('t.church')::uuid, 'active');
:as_anon
select t.ok((select count(*) from public.churches where slug = 'vases-test') = 1, 'anon sees active church');
select t.ok((select count(*) from public.search_churches('noisy')) = 1, 'search by city');
select t.fails($$ select public.join_church(current_setting('t.church')::uuid, true) $$, 'anon cannot join');

-- ---------------------------------------------------------------- content
:as_owner
update public.churches set join_mode = 'approval' where id = current_setting('t.church')::uuid;
update public.church_branding set primary_color = '#123456' where church_id = current_setting('t.church')::uuid;
select t.fails($$ update public.church_branding set primary_color = 'red' $$, 'colour must be hex');
insert into public.events (church_id, title, starts_at, capacity, registration_open, visibility, published_at)
values (current_setting('t.church')::uuid, '{"fr":"Public"}', now() + interval '7 days', 2, true, 'public', now()),
       (current_setting('t.church')::uuid, '{"fr":"Membres"}', now() + interval '7 days', null, true, 'members', now()),
       (current_setting('t.church')::uuid, '{"fr":"Brouillon"}', now() + interval '7 days', null, true, 'public', null);
select set_config('t.ev_public', (select id::text from public.events where title->>'fr' = 'Public'), false);
select t.fails($$ insert into public.events (church_id, title, starts_at) values (current_setting('t.church')::uuid, '{"de":"x"}', now()) $$, 'title locales limited to fr/en');
insert into public.announcements (church_id, title, body, audience) values
  (current_setting('t.church')::uuid, '{"fr":"Pour tous"}', '{"fr":"..."}', 'all'),
  (current_setting('t.church')::uuid, '{"fr":"Membres seulement"}', '{"fr":"..."}', 'members');

:as_anon
select t.ok((select count(*) from public.events where church_id = current_setting('t.church')::uuid) = 1, 'anon sees only published public events');
select t.ok((select count(*) from public.announcements where church_id = current_setting('t.church')::uuid) = 1, 'anon sees only audience=all announcements');
select t.ok((select capacity from public.event_seats(current_setting('t.ev_public')::uuid)) = 2, 'anon can read seat summary');

:as_bob
select t.fails($$ insert into public.events (church_id, title, starts_at) values (current_setting('t.church')::uuid, '{"fr":"Hack"}', now()) $$, 'outsider cannot create events');
update public.events set location = 'hacked' where church_id = current_setting('t.church')::uuid;
select t.ok((select count(*) from public.events where location = 'hacked') = 0, 'outsider update touches no rows');
select t.fails($$ select public.register_for_event(current_setting('t.ev_public')::uuid) $$, 'non-member cannot register');

-- ---------------------------------------------------------------- joining
:as_alice
select t.fails($$ select public.join_church(current_setting('t.church')::uuid, false) $$, 'consent is required');
select t.ok((select status from public.join_church(current_setting('t.church')::uuid, true)) = 'pending', 'approval mode -> pending');
select t.ok((select count(*) from public.events where church_id = current_setting('t.church')::uuid) = 1, 'pending member sees public events only');
select t.ok((select count(*) from public.memberships) = 1, 'member sees only own membership');
select t.ok((select count(*) from public.profiles) = 1, 'member sees only own profile');

:as_owner
select t.ok((select count(*) from public.profiles) = 2, 'owner sees profiles of own church');
select public.set_membership_status((select id from public.memberships where user_id = 'a0000000-0000-0000-0000-000000000002'), 'active');

:as_alice
select t.ok((select count(*) from public.events where church_id = current_setting('t.church')::uuid) = 2, 'active member sees members-only events');
select t.ok((select count(*) from public.announcements where church_id = current_setting('t.church')::uuid) = 2, 'active member sees members announcements');
select t.ok((select count(*) from public.profiles) = 1, 'member still cannot list other profiles');
select t.fails($$ select public.set_membership_status((select id from public.memberships limit 1), 'active') $$, 'member cannot approve');

:as_owner
insert into public.invites (church_id, code, max_uses) values (current_setting('t.church')::uuid, 'WELCOME1', 1);
:as_carol
select t.fails($$ select public.join_church(current_setting('t.church')::uuid, true, 'NOPE') $$, 'bad invite code rejected');
select t.ok((select status from public.join_church(current_setting('t.church')::uuid, true, 'welcome1')) = 'active', 'invite code -> active immediately');
:as_bob
select t.fails($$ select public.join_church(current_setting('t.church')::uuid, true, 'WELCOME1') $$, 'invite max_uses enforced');

-- ---------------------------------------------------------------- registrations
:as_alice
select t.ok((select status from public.register_for_event(current_setting('t.ev_public')::uuid, 1)) = 'confirmed', 'alice confirmed (1/2)');
select t.ok((select count(*) from public.register_for_event(current_setting('t.ev_public')::uuid, 1)) = 1, 'registering twice is idempotent');
select t.fails($$ select public.register_for_event(current_setting('t.ev_public')::uuid, 5) $$, 'seats above per-registration max rejected');
:as_carol
update public.events set max_seats_per_registration = 2 where id = current_setting('t.ev_public')::uuid;
select t.ok((select count(*) from public.events where id = current_setting('t.ev_public')::uuid and max_seats_per_registration = 2) = 0, 'member cannot edit events (no-op)');
:as_owner
update public.events set max_seats_per_registration = 2 where id = current_setting('t.ev_public')::uuid;
:as_carol
select t.ok((select status from public.register_for_event(current_setting('t.ev_public')::uuid, 2)) = 'waitlist', 'carol (2 seats) waitlisted when full');
select t.ok((select count(*) from public.event_registrations) = 1, 'member sees only own registrations');
:as_alice
select public.cancel_registration((select id from public.event_registrations where user_id = auth.uid()));
:as_carol
select t.ok((select status from public.event_registrations where user_id = auth.uid()) = 'confirmed', 'waitlist promoted after cancellation');
select t.fails($$ select * from public.check_in((select qr_token from public.event_registrations where user_id = auth.uid())) $$, 'member cannot check in');
select set_config('t.qr', (select qr_token from public.event_registrations where user_id = auth.uid()), false);
:as_owner
select t.ok((select first_name from public.check_in(current_setting('t.qr'))) = 'Carol', 'staff check-in by QR');
select t.ok((select already_checked_in from public.check_in(current_setting('t.qr'))), 'second scan flagged as already checked in');
select t.ok((select confirmed_seats from public.event_seats(current_setting('t.ev_public')::uuid)) = 2, 'seat summary counts confirmed seats');

-- ---------------------------------------------------------------- roles
:as_owner
select public.set_member_role((select id from public.memberships where user_id = 'a0000000-0000-0000-0000-000000000002'), 'admin');
:as_alice
select t.fails($$ select public.set_member_role((select id from public.memberships where user_id = 'a0000000-0000-0000-0000-000000000004'), 'admin') $$, 'admin cannot grant admin');
select public.set_member_role((select id from public.memberships where user_id = 'a0000000-0000-0000-0000-000000000004'), 'editor');
select t.fails($$ select public.set_membership_status((select id from public.memberships where role = 'owner'), 'suspended') $$, 'owner cannot be suspended');
:as_carol
insert into public.announcements (church_id, title, body) values (current_setting('t.church')::uuid, '{"en":"From editor"}', '{"en":"hi"}');
select t.ok(true, 'editor can publish announcements');
:as_owner
select t.fails($$ select public.leave_church(current_setting('t.church')::uuid) $$, 'last owner cannot leave');

-- ---------------------------------------------------------------- cross-tenant
:as_other
select set_config('t.church2', public.create_church('Autre', 'autre-eglise')::text, false);
update public.events set location = 'x' where church_id = current_setting('t.church')::uuid;
select t.ok((select count(*) from public.events where location = 'x') = 0, 'staff of church B cannot edit church A');
select t.fails($$ insert into public.events (church_id, title, starts_at) values (current_setting('t.church')::uuid, '{"fr":"x"}', now()) $$, 'staff of church B cannot insert into church A');
select t.fails($$ insert into storage.objects (bucket_id, name) values ('church-media', current_setting('t.church') || '/poster.png') $$, 'church B cannot upload into church A folder');
insert into storage.objects (bucket_id, name) values ('church-media', current_setting('t.church2') || '/logo.png');
select t.ok(true, 'staff can upload into own church folder');

-- ---------------------------------------------------------------- verse + GDPR
:as_anon
select t.ok((select reference from public.verse_of_day(null, 'LSG1910', date '2026-01-01')) = 'Jean 3:16', 'verse of the day rotation (fr)');
select t.ok((select text from public.verse_of_day(null, 'KJV', date '2026-01-02')) like 'The LORD is my shepherd%', 'verse of the day rotation (en)');
:as_carol
select t.ok((select jsonb_array_length(public.export_my_data() -> 'event_registrations')) = 1, 'export includes registrations');
select public.delete_my_data();
select t.ok((select count(*) from public.memberships) = 0, 'delete_my_data removes memberships');

reset role;
\echo 'ALL TESTS PASSED'
