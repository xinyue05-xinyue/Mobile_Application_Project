begin;
drop policy if exists events_admin_all on public.donation_events;
create policy events_admin_all on public.donation_events
for all to authenticated
using (public.is_system_admin() or (created_by = auth.uid() and exists (
  select 1 from public.profiles where id = auth.uid() and role::text = 'admin'
)))
with check (public.is_system_admin() or (created_by = auth.uid() and exists (
  select 1 from public.profiles where id = auth.uid() and role::text = 'admin'
)));

create or replace function public.keep_event_owner()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.created_by is distinct from old.created_by then
    raise exception 'Event ownership cannot be changed';
  end if;
  return new;
end;
$$;
drop trigger if exists keep_event_owner on public.donation_events;
create trigger keep_event_owner before update on public.donation_events
for each row execute function public.keep_event_owner();

create table if not exists public.feedback_replies (
  id uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.feedback(id) on delete cascade,
  author_id uuid references public.profiles(id) on delete set null,
  message text not null check (char_length(trim(message)) between 1 and 2000),
  created_at timestamptz not null default now(),
  legacy boolean not null default false
);
create unique index if not exists feedback_reply_legacy_idx
on public.feedback_replies(feedback_id) where legacy;
alter table public.feedback_replies enable row level security;
grant select on public.feedback_replies to authenticated;
revoke insert, update, delete on public.feedback_replies from authenticated;
drop policy if exists feedback_replies_read on public.feedback_replies;
create policy feedback_replies_read on public.feedback_replies for select to authenticated
using (public.is_system_admin() or exists (
  select 1 from public.feedback f where f.id = feedback_id and f.user_id = auth.uid()
));
insert into public.feedback_replies(feedback_id, message, created_at, legacy)
select id, admin_response, updated_at, true from public.feedback
where nullif(trim(admin_response), '') is not null
on conflict (feedback_id) where legacy do nothing;

create or replace function public.review_feedback(p_feedback_id uuid, p_status text, p_response text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not public.is_system_admin() then
    raise exception 'Only system administrators can reply';
  end if;
  if p_status is null or p_status not in ('open', 'reviewed', 'resolved') then
    raise exception 'Invalid feedback status';
  end if;
  perform 1 from public.feedback where id = p_feedback_id for update;
  if not found then raise exception 'Feedback not found'; end if;
  if nullif(trim(p_response), '') is not null then
    insert into public.feedback_replies(feedback_id, author_id, message)
      values (p_feedback_id, auth.uid(), trim(p_response));
  end if;
  update public.feedback set status = p_status,
    admin_response = coalesce(nullif(trim(p_response), ''), admin_response),
    updated_at = now() where id = p_feedback_id;
end;
$$;
revoke update on public.feedback from authenticated;
drop policy if exists feedback_create on public.feedback;
create policy feedback_create on public.feedback for insert to authenticated
with check (user_id = auth.uid() and status = 'open' and admin_response is null);
revoke all on function public.review_feedback(uuid, text, text) from public;
grant execute on function public.review_feedback(uuid, text, text) to authenticated;
commit;
