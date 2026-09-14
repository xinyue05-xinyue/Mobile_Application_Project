begin;

alter table public.donation_events
  drop constraint if exists donation_events_status_check;

update public.donation_events
set status = case
  when status = 'cancelled' then 'cancelled'
  when ends_at <= now() then 'ended'
  when starts_at <= now() then 'in_progress'
  else 'upcoming'
end,
updated_at = now();

alter table public.donation_events
  add constraint donation_events_status_check
  check (status in ('upcoming', 'in_progress', 'ended', 'cancelled'));

create or replace function public.set_donation_event_status()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status <> 'cancelled' then
    new.status := case
      when new.ends_at <= now() then 'ended'
      when new.starts_at <= now() then 'in_progress'
      else 'upcoming'
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists donation_events_set_status on public.donation_events;
create trigger donation_events_set_status
before insert or update of starts_at, ends_at, status
on public.donation_events
for each row
execute function public.set_donation_event_status();

create or replace function public.sync_donation_event_statuses()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_count integer;
begin
  update public.donation_events
  set status = case
    when ends_at <= now() then 'ended'
    when starts_at <= now() then 'in_progress'
    else 'upcoming'
  end,
  updated_at = now()
  where status <> 'cancelled'
    and status is distinct from case
      when ends_at <= now() then 'ended'
      when starts_at <= now() then 'in_progress'
      else 'upcoming'
    end;

  get diagnostics changed_count = row_count;
  return changed_count;
end;
$$;

revoke all on function public.sync_donation_event_statuses() from public;
grant execute on function public.sync_donation_event_statuses() to service_role;

create extension if not exists pg_cron with schema extensions;

do $$
begin
  if not exists (
    select 1 from cron.job
    where jobname = 'sync-mydarah-event-statuses'
  ) then
    perform cron.schedule(
      'sync-mydarah-event-statuses',
      '* * * * *',
      'select public.sync_donation_event_statuses();'
    );
  end if;
end;
$$;

drop policy if exists event_registrations_insert on public.event_registrations;
create policy event_registrations_insert on public.event_registrations
for insert to authenticated
with check (
  donor_id = auth.uid()
  and exists (
    select 1 from public.donation_events event
    where event.id = event_id
      and event.status in ('upcoming', 'in_progress')
      and event.ends_at > now()
  )
);

create or replace function public.register_for_event(p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_event public.donation_events%rowtype;
  donor_profile public.profiles%rowtype;
  registration_id uuid;
  event_date date;
begin
  if auth.uid() is null then
    raise exception 'Please log in again';
  end if;

  select * into selected_event
  from public.donation_events
  where id = p_event_id
    and status in ('upcoming', 'in_progress')
    and ends_at > now();

  if not found then
    raise exception 'This event has ended or is no longer available for registration';
  end if;

  select * into donor_profile
  from public.profiles
  where id = auth.uid()
    and role::text = 'donor';

  if not found then
    raise exception 'Only donor accounts can register for events';
  end if;

  event_date := (selected_event.starts_at at time zone 'Asia/Kuala_Lumpur')::date;
  if donor_profile.next_eligible_date is not null
     and donor_profile.next_eligible_date > event_date then
    raise exception 'Not eligible for this event. You can donate again from %',
      to_char(donor_profile.next_eligible_date, 'DD/MM/YYYY');
  end if;

  insert into public.event_registrations (event_id, donor_id)
  values (p_event_id, auth.uid())
  returning id into registration_id;

  return registration_id;
exception
  when unique_violation then
    raise exception 'You have already registered for this event';
end;
$$;

revoke all on function public.register_for_event(uuid) from public;
grant execute on function public.register_for_event(uuid) to authenticated;

create or replace function public.verify_event_qr(
  p_event_id uuid,
  p_donor_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_registration public.event_registrations%rowtype;
  selected_event public.donation_events%rowtype;
  new_donation_id uuid;
  donation_day date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
begin
  select * into selected_event
  from public.donation_events
  where id = p_event_id and created_by = auth.uid();

  if not found then
    raise exception 'Only the event owner can scan attendance';
  end if;

  if selected_event.status <> 'in_progress'
     or selected_event.starts_at > now()
     or selected_event.ends_at <= now() then
    raise exception 'Attendance scanning is available only while the event is in progress';
  end if;

  select * into selected_registration
  from public.event_registrations
  where event_id = p_event_id
    and donor_id = p_donor_id
    and status = 'registered'
  for update;

  if not found then
    raise exception 'Active donor registration not found';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_donor_id
      and (next_eligible_date is null or next_eligible_date <= donation_day)
  ) then
    raise exception 'Donor is not currently eligible';
  end if;

  insert into public.donations (
    donor_id, donation_date, verification_status, verified_by, verified_at,
    event_id
  ) values (
    p_donor_id, donation_day, 'verified', auth.uid(), now(), p_event_id
  ) returning id into new_donation_id;

  insert into public.reward_transactions (
    donor_id, points, transaction_type, donation_id
  ) values (p_donor_id, 100, 'earned', new_donation_id);

  update public.profiles
  set next_eligible_date = (donation_day + interval '3 months')::date,
      updated_at = now()
  where id = p_donor_id;

  update public.event_registrations
  set status = 'attended', attended_at = now()
  where id = selected_registration.id;

  return new_donation_id;
end;
$$;

revoke all on function public.verify_event_qr(uuid, uuid) from public;
grant execute on function public.verify_event_qr(uuid, uuid) to authenticated;

select public.sync_donation_event_statuses();

commit;
