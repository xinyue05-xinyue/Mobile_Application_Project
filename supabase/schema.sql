create extension if not exists pgcrypto;

create type public.user_role as enum ('donor', 'hospital_admin');
create type public.request_status as enum ('active', 'fulfilled', 'cancelled');
create type public.verification_status as enum ('pending', 'verified', 'rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.user_role not null default 'donor',
  blood_type text check (blood_type in ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
  phone text,
  date_of_birth date,
  next_eligible_date date,
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.donation_centres (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  state text not null,
  latitude double precision not null,
  longitude double precision not null,
  operating_hours text,
  source_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.donation_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  venue text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'upcoming' check (status in ('upcoming', 'in_progress', 'ended', 'cancelled')),
  description text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  publish_at timestamptz not null default now(),
  published_notified_at timestamptz,
  check (publish_at <= starts_at),
  check (ends_at > starts_at)
);

create table public.emergency_requests (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.profiles(id),
  blood_type text not null check (blood_type in ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
  units_needed integer not null check (units_needed > 0),
  urgency text not null check (urgency in ('normal', 'urgent', 'critical')),
  deadline timestamptz not null,
  status public.request_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.donations (
  id uuid primary key default gen_random_uuid(),
  donor_id uuid not null references public.profiles(id),
  centre_id uuid references public.donation_centres(id),
  donation_date date not null,
  verification_status public.verification_status not null default 'pending',
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.reward_transactions (
  id uuid primary key default gen_random_uuid(),
  donor_id uuid not null references public.profiles(id),
  points integer not null,
  transaction_type text not null check (transaction_type in ('earned', 'redeemed', 'adjustment')),
  donation_id uuid unique references public.donations(id),
  created_at timestamptz not null default now()
);

create or replace function public.is_hospital_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'hospital_admin'
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', 'New donor'));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.donation_centres enable row level security;
alter table public.donation_events enable row level security;
alter table public.emergency_requests enable row level security;
alter table public.donations enable row level security;
alter table public.reward_transactions enable row level security;

create policy profiles_select on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_hospital_admin());

create policy profiles_update on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

revoke update on public.profiles from authenticated;
grant update (full_name, blood_type, phone, date_of_birth, notifications_enabled)
on public.profiles to authenticated;

create policy centres_read on public.donation_centres
for select to authenticated using (true);

create policy centres_admin_all on public.donation_centres
for all to authenticated
using (public.is_hospital_admin())
with check (public.is_hospital_admin());

create policy events_read on public.donation_events
for select to authenticated using (
  publish_at <= now()
  or created_by = auth.uid()
  or public.is_system_admin()
);

create policy events_admin_all on public.donation_events
for all to authenticated
using (public.is_hospital_admin())
with check (public.is_hospital_admin());

create policy requests_read on public.emergency_requests
for select to authenticated
using (status = 'active' or hospital_id = auth.uid());

create policy requests_admin_all on public.emergency_requests
for all to authenticated
using (public.is_hospital_admin())
with check (public.is_hospital_admin() and hospital_id = auth.uid());

create policy donations_read on public.donations
for select to authenticated
using (donor_id = auth.uid() or public.is_hospital_admin());

create policy donations_admin_all on public.donations
for all to authenticated
using (public.is_hospital_admin())
with check (public.is_hospital_admin());

create policy rewards_read on public.reward_transactions
for select to authenticated
using (donor_id = auth.uid() or public.is_hospital_admin());

create policy rewards_admin_all on public.reward_transactions
for all to authenticated
using (public.is_hospital_admin())
with check (public.is_hospital_admin());

create index donation_events_starts_at_idx on public.donation_events(starts_at);
create index emergency_requests_blood_status_idx on public.emergency_requests(blood_type, status);
create index donations_donor_date_idx on public.donations(donor_id, donation_date desc);
create index reward_transactions_donor_idx on public.reward_transactions(donor_id, created_at desc);
