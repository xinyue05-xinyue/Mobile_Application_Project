begin;

alter table public.donation_events
  add column if not exists publish_at timestamptz;
alter table public.donation_events
  add column if not exists published_notified_at timestamptz;

update public.donation_events
set publish_at = least(
  coalesce(created_at, starts_at, now()),
  starts_at
)
where publish_at is null;

update public.donation_events
set publish_at = starts_at
where publish_at > starts_at;

alter table public.donation_events
  alter column publish_at set default now();
alter table public.donation_events
  alter column publish_at set not null;

alter table public.donation_events
  drop constraint if exists donation_events_publish_before_start;
alter table public.donation_events
  add constraint donation_events_publish_before_start
  check (publish_at <= starts_at);

drop policy if exists events_read on public.donation_events;
create policy events_read on public.donation_events
for select to authenticated
using (
  publish_at <= now()
  or created_by = auth.uid()
  or public.is_system_admin()
);

create or replace function public.publish_scheduled_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_event public.donation_events%rowtype;
  published_count integer := 0;
begin
  for selected_event in
    select * from public.donation_events
    where publish_at <= now()
      and published_notified_at is null
      and status <> 'cancelled'
    for update skip locked
  loop
    insert into public.notifications (
      user_id, title, message, type, reference_type, reference_id
    )
    select
      profile.id,
      'New blood donation event',
      selected_event.title || ' starts on ' ||
        to_char(
          selected_event.starts_at at time zone 'Asia/Kuala_Lumpur',
          'DD/MM/YYYY HH24:MI'
        ) || '.',
      'event',
      'donation_event',
      selected_event.id
    from public.profiles profile
    where profile.role::text = 'donor'
      and profile.notifications_enabled;

    update public.donation_events
    set published_notified_at = now(), updated_at = now()
    where id = selected_event.id;
    published_count := published_count + 1;
  end loop;
  return published_count;
end;
$$;

revoke all on function public.publish_scheduled_events() from public;
grant execute on function public.publish_scheduled_events() to service_role;

create extension if not exists pg_cron with schema extensions;
do $$
begin
  if not exists (select 1 from cron.job where jobname = 'publish-mydarah-events') then
    perform cron.schedule(
      'publish-mydarah-events',
      '* * * * *',
      'select public.publish_scheduled_events();'
    );
  end if;
end;
$$;

select public.publish_scheduled_events();

commit;
