begin;

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

  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

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

  if donor_profile.date_of_birth is null then
    raise exception 'Add your date of birth in Profile before registering';
  end if;

  if donor_profile.date_of_birth > current_date - interval '18 years' then
    raise exception 'You must be at least 18 years old to register';
  end if;

  if donor_profile.phone is null
     or donor_profile.phone !~ '^0[0-9]{9,10}$' then
    raise exception 'Add a valid Malaysian phone number in Profile before registering';
  end if;

  if exists (
    select 1
    from public.event_registrations registration
    join public.donation_events event on event.id = registration.event_id
    where registration.donor_id = auth.uid()
      and registration.status = 'registered'
      and registration.event_id <> p_event_id
      and event.status not in ('ended', 'cancelled')
      and event.ends_at > now()
  ) then
    raise exception 'You are already registered for another active event';
  end if;

  if exists (
    select 1
    from public.emergency_responses response
    join public.emergency_requests request on request.id = response.request_id
    where response.donor_id = auth.uid()
      and response.status = 'pending'
      and request.status = 'active'
      and request.deadline > now()
  ) then
    raise exception 'You already have an active emergency donation response';
  end if;

  event_date := (selected_event.starts_at at time zone 'Asia/Kuala_Lumpur')::date;
  if donor_profile.next_eligible_date is not null
     and donor_profile.next_eligible_date > event_date then
    raise exception 'Not eligible for this event. You can donate again from %',
      to_char(donor_profile.next_eligible_date, 'DD/MM/YYYY');
  end if;

  insert into public.event_registrations (event_id, donor_id)
  values (p_event_id, auth.uid())
  on conflict (event_id, donor_id) do update
  set status = 'registered',
      registered_at = now(),
      attended_at = null
  where public.event_registrations.status = 'cancelled'
  returning id into registration_id;

  if registration_id is null then
    raise exception 'You have already registered for this event';
  end if;

  return registration_id;
exception
  when unique_violation then
    raise exception 'You have already registered for this event';
end;
$$;

revoke all on function public.register_for_event(uuid) from public;
grant execute on function public.register_for_event(uuid) to authenticated;

revoke insert on public.event_registrations from authenticated;
drop policy if exists event_registrations_insert on public.event_registrations;

create or replace function public.cancel_my_event_registration(p_event_id uuid)
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
  set status = 'cancelled'
  from public.donation_events event
  where registration.event_id = p_event_id
    and registration.donor_id = auth.uid()
    and registration.status = 'registered'
    and event.id = registration.event_id
    and event.status not in ('ended', 'cancelled')
    and event.ends_at > now();

  if not found then
    raise exception 'Active registration not found';
  end if;

  update public.event_email_reminders
  set status = 'cancelled'
  where user_id = auth.uid()
    and event_id = p_event_id
    and status in ('pending', 'sending');
end;
$$;

revoke all on function public.cancel_my_event_registration(uuid) from public;
grant execute on function public.cancel_my_event_registration(uuid)
to authenticated;

create or replace function public.respond_to_emergency(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_request public.emergency_requests%rowtype;
  donor_profile public.profiles%rowtype;
  response_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Please log in again';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));

  select * into selected_request
  from public.emergency_requests
  where id = p_request_id
    and status = 'active'
    and deadline > now();

  if not found then
    raise exception 'This emergency request is no longer active';
  end if;

  select * into donor_profile
  from public.profiles
  where id = auth.uid()
    and role::text = 'donor';

  if not found then
    raise exception 'Only donor accounts can respond to emergency requests';
  end if;

  if donor_profile.date_of_birth is null then
    raise exception 'Add your date of birth in Profile before responding';
  end if;

  if donor_profile.date_of_birth > current_date - interval '18 years' then
    raise exception 'You must be at least 18 years old to respond';
  end if;

  if donor_profile.phone is null
     or donor_profile.phone !~ '^0[0-9]{9,10}$' then
    raise exception 'Add a valid Malaysian phone number in Profile before responding';
  end if;

  if donor_profile.blood_type is distinct from selected_request.blood_type then
    raise exception 'This request does not match your blood type';
  end if;

  if donor_profile.next_eligible_date is not null
     and donor_profile.next_eligible_date > current_date then
    raise exception 'You can donate again from %',
      to_char(donor_profile.next_eligible_date, 'DD/MM/YYYY');
  end if;

  if exists (
    select 1
    from public.event_registrations registration
    join public.donation_events event on event.id = registration.event_id
    where registration.donor_id = auth.uid()
      and registration.status = 'registered'
      and event.status not in ('ended', 'cancelled')
      and event.ends_at > now()
  ) then
    raise exception 'You are already registered for an active donation event';
  end if;

  if exists (
    select 1
    from public.emergency_responses response
    join public.emergency_requests request on request.id = response.request_id
    where response.donor_id = auth.uid()
      and response.status = 'pending'
      and request.status = 'active'
      and request.deadline > now()
      and response.request_id <> p_request_id
  ) then
    raise exception 'You already have another active emergency donation response';
  end if;

  insert into public.emergency_responses (request_id, donor_id)
  values (p_request_id, auth.uid())
  on conflict (request_id, donor_id) do update
  set status = 'pending',
      created_at = now(),
      completed_at = null
  where public.emergency_responses.status in ('cancelled', 'expired')
  returning id into response_id;

  if response_id is null then
    raise exception 'You have already responded to this emergency request';
  end if;

  return response_id;
exception
  when unique_violation then
    raise exception 'You have already responded to this emergency request';
end;
$$;

revoke all on function public.respond_to_emergency(uuid) from public;
grant execute on function public.respond_to_emergency(uuid) to authenticated;

revoke insert on public.emergency_responses from authenticated;
drop policy if exists emergency_responses_insert on public.emergency_responses;

create or replace function public.has_active_donation_commitment()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.event_registrations registration
    join public.donation_events event on event.id = registration.event_id
    where registration.donor_id = auth.uid()
      and registration.status = 'registered'
      and event.status not in ('ended', 'cancelled')
      and event.ends_at > now()
  ) or exists (
    select 1
    from public.emergency_responses response
    join public.emergency_requests request on request.id = response.request_id
    where response.donor_id = auth.uid()
      and response.status = 'pending'
      and request.status = 'active'
      and request.deadline > now()
  );
$$;

revoke all on function public.has_active_donation_commitment() from public;
grant execute on function public.has_active_donation_commitment() to authenticated;

commit;
