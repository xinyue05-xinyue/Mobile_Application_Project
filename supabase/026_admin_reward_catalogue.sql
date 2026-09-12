-- Run once in Supabase SQL Editor after 020_reward_history_links.sql.
-- Adds administrator-managed reward icons/images and catalogue permissions.

begin;

alter table public.reward_items
  add column if not exists icon_key text not null default 'other',
  add column if not exists image_url text,
  add column if not exists updated_at timestamptz not null default now();

update public.reward_items
set icon_key = case
  when name ilike '%t-shirt%' then 'shirt'
  when name ilike '%bag%' then 'bag'
  when name ilike '%meal%' then 'meal'
  when category = 'voucher' then 'voucher'
  else 'gift'
end
where icon_key = 'other';

grant insert, update, delete on public.reward_items to authenticated;

drop policy if exists reward_items_admin_insert on public.reward_items;
create policy reward_items_admin_insert on public.reward_items
for insert to authenticated
with check (public.is_system_admin());

drop policy if exists reward_items_admin_update on public.reward_items;
create policy reward_items_admin_update on public.reward_items
for update to authenticated
using (public.is_system_admin())
with check (public.is_system_admin());

drop policy if exists reward_items_admin_delete on public.reward_items;
create policy reward_items_admin_delete on public.reward_items
for delete to authenticated
using (public.is_system_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'reward-images',
  'reward-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists reward_images_admin_insert on storage.objects;
create policy reward_images_admin_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'reward-images'
  and public.is_system_admin()
);

drop policy if exists reward_images_admin_update on storage.objects;
create policy reward_images_admin_update on storage.objects
for update to authenticated
using (bucket_id = 'reward-images' and public.is_system_admin())
with check (bucket_id = 'reward-images' and public.is_system_admin());

drop policy if exists reward_images_admin_delete on storage.objects;
create policy reward_images_admin_delete on storage.objects
for delete to authenticated
using (bucket_id = 'reward-images' and public.is_system_admin());

commit;
