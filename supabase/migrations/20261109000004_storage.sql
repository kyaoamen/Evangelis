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
