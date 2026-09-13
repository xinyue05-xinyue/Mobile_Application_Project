create table public.event_email_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid not null references public.donation_events(id) on delete cascade,
  remind_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','sending','sent','cancelled','failed')),
  attempts integer not null default 0,
  locked_at timestamptz,
  sent_at timestamptz,
  last_error text,
  email_payload jsonb,
  unique(user_id, event_id)
);
alter table public.event_email_reminders enable row level security;
revoke all on public.event_email_reminders from anon, authenticated;
grant select on public.event_email_reminders to authenticated;
grant all on public.event_email_reminders to service_role;
create policy reminder_read_own on public.event_email_reminders
  for select to authenticated using (user_id = auth.uid());
create index event_email_reminders_due on public.event_email_reminders(remind_at)
  where status in ('pending','sending');

create or replace function public.set_event_email_reminder(p_event_id uuid, p_remind_at timestamptz)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Please log in again'; end if;
  if p_remind_at is null then
    update public.event_email_reminders set status = 'cancelled'
      where user_id = auth.uid() and event_id = p_event_id;
    return;
  end if;
  if not exists (select 1 from auth.users where id = auth.uid()
    and email is not null and email_confirmed_at is not null) then
    raise exception 'Please verify your login email first';
  end if;
  if not exists (select 1 from public.profiles where id = auth.uid() and notifications_enabled) then
    raise exception 'Enable event notifications in your profile first';
  end if;
  if not exists (
    select 1 from public.event_registrations r join public.donation_events e on e.id = r.event_id
    where r.donor_id = auth.uid() and r.event_id = p_event_id and r.status = 'registered'
      and e.status <> 'cancelled' and p_remind_at > now() and p_remind_at < e.starts_at
  ) then raise exception 'Choose a future time before your registered event starts'; end if;
  insert into public.event_email_reminders(user_id,event_id,remind_at)
    values(auth.uid(),p_event_id,p_remind_at)
    on conflict(user_id,event_id) do update set id = gen_random_uuid(), remind_at = excluded.remind_at,
      status = 'pending', attempts = 0, locked_at = null, sent_at = null, last_error = null, email_payload = null;
end; $$;
revoke all on function public.set_event_email_reminder(uuid,timestamptz) from public, anon;
grant execute on function public.set_event_email_reminder(uuid,timestamptz) to authenticated;

create or replace function public.claim_event_email_reminders(p_sender text)
returns setof public.event_email_reminders language plpgsql security definer set search_path = public as $$
declare item public.event_email_reminders%rowtype; event_row public.donation_events%rowtype; recipient text;
begin
  for item in select * from public.event_email_reminders
    where remind_at <= now() and (status = 'pending' or (status = 'sending' and locked_at < now() - interval '5 minutes'))
    order by remind_at limit 10 for update skip locked
  loop
    select * into event_row from public.donation_events where id = item.event_id;
    if event_row.starts_at <= now() or event_row.status = 'cancelled' or not exists (
      select 1 from public.event_registrations where donor_id = item.user_id and event_id = item.event_id and status = 'registered'
    ) or not exists (select 1 from public.profiles where id = item.user_id and notifications_enabled) then
      update public.event_email_reminders set status = 'cancelled' where id = item.id;
      continue;
    end if;
    if item.attempts >= 5 or item.remind_at < now() - interval '20 hours' then
      update public.event_email_reminders set status = 'failed' where id = item.id;
      continue;
    end if;
    select email into recipient from auth.users where id = item.user_id and email_confirmed_at is not null;
    if recipient is null then
      update public.event_email_reminders set status = 'failed', last_error = 'No verified login email' where id = item.id;
      continue;
    end if;
    update public.event_email_reminders set status = 'sending', locked_at = now(), attempts = attempts + 1,
      email_payload = coalesce(email_payload, jsonb_build_object(
        'from', p_sender, 'to', recipient, 'subject', 'MyDarah event reminder',
        'text', 'Reminder: ' || event_row.title || E'\nVenue: ' || event_row.venue || E'\nStarts: ' ||
          to_char(event_row.starts_at at time zone 'Asia/Kuala_Lumpur','DD/MM/YYYY HH24:MI') ||
          E' (Malaysia time)\n\nOpen MyDarah for event details. You can manage reminders in Events and notification preferences in Profile.'
      )) where id = item.id returning * into item;
    insert into public.notifications(id,user_id,title,message,type,reference_type,reference_id)
      values(item.id,item.user_id,'Event reminder',event_row.title || ' starts soon at ' || event_row.venue,
        'event','event',item.event_id) on conflict(id) do nothing;
    return next item;
  end loop;
end; $$;
revoke all on function public.claim_event_email_reminders(text) from public, anon, authenticated;
grant execute on function public.claim_event_email_reminders(text) to service_role;
