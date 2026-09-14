begin;

drop trigger if exists emergency_response_fulfil_request
on public.emergency_responses;
drop function if exists public.sync_emergency_request_fulfilment();

alter table public.event_registrations
  drop constraint if exists event_registrations_status_check;
alter table public.event_registrations
  add constraint event_registrations_status_check
  check (status in ('registered', 'attended', 'cancelled', 'expired'));

alter table public.emergency_responses
  drop constraint if exists emergency_responses_status_check;
alter table public.emergency_responses
  add constraint emergency_responses_status_check
  check (status in ('pending', 'completed', 'cancelled', 'expired'));

create or replace function public.sync_expired_donation_commitments()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_count integer;
  event_count integer;
  emergency_count integer;
begin
  update public.event_registrations registration
  set status = 'expired'
  from public.donation_events event
  where registration.event_id = event.id
    and registration.status = 'registered'
    and (event.ends_at <= now() or event.status in ('ended', 'cancelled'));
  get diagnostics event_count = row_count;

  update public.emergency_responses response
  set status = 'expired'
  from public.emergency_requests request
  where response.request_id = request.id
    and response.status = 'pending'
    and (request.deadline <= now() or request.status <> 'active');
  get diagnostics emergency_count = row_count;

  changed_count := event_count + emergency_count;
  return changed_count;
end;
$$;

revoke all on function public.sync_expired_donation_commitments() from public;
grant execute on function public.sync_expired_donation_commitments()
to service_role;

create or replace function public.refresh_my_donation_commitments()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Please log in again';
  end if;

  update public.event_registrations registration
  set status = 'expired'
  from public.donation_events event
  where registration.event_id = event.id
    and registration.donor_id = auth.uid()
    and registration.status = 'registered'
    and (event.ends_at <= now() or event.status in ('ended', 'cancelled'));

  update public.emergency_responses response
  set status = 'expired'
  from public.emergency_requests request
  where response.request_id = request.id
    and response.donor_id = auth.uid()
    and response.status = 'pending'
    and (request.deadline <= now() or request.status <> 'active');
end;
$$;

revoke all on function public.refresh_my_donation_commitments() from public;
grant execute on function public.refresh_my_donation_commitments()
to authenticated;

select public.sync_expired_donation_commitments();

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and not exists (
       select 1 from cron.job
       where jobname = 'sync-expired-donation-commitments'
     ) then
    perform cron.schedule(
      'sync-expired-donation-commitments',
      '* * * * *',
      'select public.sync_expired_donation_commitments();'
    );
  end if;
end;
$$;

create or replace function public.cancel_my_emergency_response(
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Please log in again';
  end if;

  update public.emergency_responses response
  set status = 'cancelled'
  from public.emergency_requests request
  where response.request_id = p_request_id
    and response.donor_id = auth.uid()
    and response.status = 'pending'
    and request.id = response.request_id
    and request.status = 'active'
    and request.deadline > now();

  if not found then
    perform public.sync_expired_donation_commitments();
    raise exception 'Active emergency response not found';
  end if;
end;
$$;

revoke all on function public.cancel_my_emergency_response(uuid) from public;
grant execute on function public.cancel_my_emergency_response(uuid)
to authenticated;

create or replace function public.verify_emergency_donation(
  p_response_id uuid,
  p_next_eligible_date date
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_response public.emergency_responses%rowtype;
  selected_request public.emergency_requests%rowtype;
  new_donation_id uuid;
begin
  perform public.sync_expired_donation_commitments();

  select * into selected_response
  from public.emergency_responses
  where id = p_response_id and status = 'pending'
  for update;

  if not found then raise exception 'Pending response not found'; end if;

  select * into selected_request
  from public.emergency_requests
  where id = selected_response.request_id
    and hospital_id = auth.uid()
  for update;

  if not found then
    raise exception 'Only the owning hospital can verify this donation';
  end if;
  if selected_request.status <> 'active'
     or selected_request.deadline <= now() then
    raise exception 'This emergency request is already closed';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role::text in ('hospital', 'system_admin')
  ) then raise exception 'Hospital access required'; end if;
  if p_next_eligible_date <= current_date then
    raise exception 'Next eligible date must be in the future';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = selected_response.donor_id
      and (next_eligible_date is null or next_eligible_date <= current_date)
  ) then raise exception 'Donor is not currently eligible'; end if;

  insert into public.donations (
    donor_id, donation_date, verification_status, verified_by,
    verified_at, emergency_request_id
  ) values (
    selected_response.donor_id, current_date, 'verified', auth.uid(),
    now(), selected_response.request_id
  ) returning id into new_donation_id;

  insert into public.reward_transactions (
    donor_id, points, transaction_type, donation_id
  ) values (selected_response.donor_id, 150, 'earned', new_donation_id);

  update public.profiles
  set next_eligible_date = p_next_eligible_date, updated_at = now()
  where id = selected_response.donor_id;

  update public.emergency_responses
  set status = 'completed', completed_at = now()
  where id = p_response_id;

  return new_donation_id;
end;
$$;

revoke all on function public.verify_emergency_donation(uuid, date)
from public;
grant execute on function public.verify_emergency_donation(uuid, date)
to authenticated;

alter table public.emergency_requests
  drop column if exists units_needed;

commit;
