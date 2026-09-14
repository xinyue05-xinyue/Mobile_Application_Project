begin;

alter table public.profiles
  drop constraint if exists profiles_full_name_format_check;
alter table public.profiles
  add constraint profiles_full_name_format_check
  check (full_name ~ '^[A-Za-z]+( [A-Za-z]+)*$') not valid;

alter table public.profiles
  drop constraint if exists profiles_phone_format_check;
alter table public.profiles
  add constraint profiles_phone_format_check
  check (phone is null or phone ~ '^0[0-9]{9,10}$') not valid;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, date_of_birth)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'New donor'),
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date
  );
  return new;
end;
$$;

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

drop policy if exists event_registrations_insert on public.event_registrations;
create policy event_registrations_insert on public.event_registrations
for insert to authenticated
with check (
  donor_id = auth.uid()
  and exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role::text = 'donor'
      and profile.date_of_birth is not null
      and profile.date_of_birth <= current_date - interval '18 years'
      and profile.phone ~ '^0[0-9]{9,10}$'
  )
  and exists (
    select 1
    from public.donation_events event
    where event.id = event_id
      and event.status in ('upcoming', 'in_progress')
      and event.ends_at > now()
  )
);

commit;
