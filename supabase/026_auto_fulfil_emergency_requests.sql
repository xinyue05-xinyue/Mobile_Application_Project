-- Fulfil emergency requests as soon as their verified donations reach the
-- requested unit count. The trigger runs in the verification transaction.
create or replace function public.sync_emergency_request_fulfilment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed' then
    update public.emergency_requests request
    set status = 'fulfilled', updated_at = now()
    where request.id = new.request_id
      and request.status = 'active'
      and (
        select count(*)
        from public.emergency_responses response
        where response.request_id = new.request_id
          and response.status = 'completed'
      ) >= request.units_needed;
  end if;

  return new;
end;
$$;

drop trigger if exists emergency_response_fulfil_request
on public.emergency_responses;
create trigger emergency_response_fulfil_request
after insert or update of status on public.emergency_responses
for each row
execute function public.sync_emergency_request_fulfilment();

-- Repair requests completed before this trigger existed.
update public.emergency_requests request
set status = 'fulfilled', updated_at = now()
where request.status = 'active'
  and (
    select count(*)
    from public.emergency_responses response
    where response.request_id = request.id
      and response.status = 'completed'
  ) >= request.units_needed;

-- Prevent an already fulfilled request from accepting another verification.
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
  if selected_request.status <> 'active' then
    raise exception 'This emergency request is already closed';
  end if;
  if (
    select count(*)
    from public.emergency_responses
    where request_id = selected_request.id and status = 'completed'
  ) >= selected_request.units_needed then
    raise exception 'The requested donation units have already been fulfilled';
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

revoke all on function public.verify_emergency_donation(uuid, date) from public;
grant execute on function public.verify_emergency_donation(uuid, date)
to authenticated;
