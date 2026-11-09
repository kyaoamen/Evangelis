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
