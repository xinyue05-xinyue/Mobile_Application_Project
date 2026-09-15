alter table public.profiles
  add column if not exists state text;

alter table public.profiles
  drop constraint if exists profiles_state_check;

alter table public.profiles
  add constraint profiles_state_check check (
    state is null or state in (
      'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan',
      'Pahang', 'Perak', 'Perlis', 'Pulau Pinang', 'Sabah', 'Sarawak',
      'Selangor', 'Terengganu', 'Kuala Lumpur', 'Putrajaya', 'Labuan'
    )
  );

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    phone,
    date_of_birth,
    state
  )
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), 'New donor'),
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    nullif(new.raw_user_meta_data ->> 'date_of_birth', '')::date,
    nullif(new.raw_user_meta_data ->> 'state', '')
  );
  return new;
end;
$$;

grant update (
  full_name,
  blood_type,
  phone,
  date_of_birth,
  notifications_enabled,
  state
) on public.profiles to authenticated;
