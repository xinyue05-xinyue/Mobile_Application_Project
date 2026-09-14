drop trigger if exists emergency_response_fulfil_request
on public.emergency_responses;
drop function if exists public.sync_emergency_request_fulfilment();

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
