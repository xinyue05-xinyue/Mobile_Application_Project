begin;

alter table public.role_requests
drop constraint if exists role_requests_status_check;

alter table public.role_requests
add constraint role_requests_status_check
check (status in ('pending', 'approved', 'rejected', 'removed'));

alter table public.notifications
drop constraint if exists notifications_type_check;

alter table public.notifications
add constraint notifications_type_check
check (type in ('emergency', 'event', 'role', 'reward', 'feedback', 'general'));

create or replace function public.demote_staff_to_donor(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_role text;
  removed_request_id uuid;
begin
  if not public.is_system_admin() then
    raise exception 'Only a system administrator can manage staff roles';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot remove your own system administrator access';
  end if;

  select role::text into target_role
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'Account not found';
  end if;

  if target_role not in ('admin', 'hospital', 'hospital_admin') then
    raise exception 'Only organisation admin or hospital access can be removed';
  end if;

  update public.profiles
  set role = 'donor', updated_at = now()
  where id = p_user_id;

  select id into removed_request_id
  from public.role_requests
  where user_id = p_user_id
    and status = 'approved'
  order by reviewed_at desc nulls last, created_at desc
  limit 1
  for update;

  if removed_request_id is not null then
    update public.role_requests
    set status = 'removed',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        rejection_reason = null
    where id = removed_request_id;
  end if;

  insert into public.notifications (
    user_id, title, message, type, reference_type, reference_id
  ) values (
    p_user_id,
    'Staff access removed',
    case
      when target_role = 'admin' then
        'Your organisation administrator access has been removed. Your account is now a donor account.'
      else
        'Your hospital administrator access has been removed. Your account is now a donor account.'
    end,
    'role',
    'role_request',
    removed_request_id
  );
end;
$$;

revoke all on function public.demote_staff_to_donor(uuid) from public;
grant execute on function public.demote_staff_to_donor(uuid) to authenticated;

create or replace function public.notify_new_role_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (
    user_id, title, message, type, reference_type, reference_id
  )
  select
    profile.id,
    'New staff access application',
    coalesce(applicant.full_name, 'A user') || ' applied for ' ||
      case
        when new.requested_role::text = 'admin' then 'organisation administrator access.'
        else 'hospital administrator access.'
      end,
    'role',
    'role_request',
    new.id
  from public.profiles profile
  left join public.profiles applicant on applicant.id = new.user_id
  where profile.role::text = 'system_admin';
  return new;
end;
$$;

drop trigger if exists notify_new_role_request_trigger on public.role_requests;
create trigger notify_new_role_request_trigger
after insert on public.role_requests
for each row execute function public.notify_new_role_request();

create or replace function public.notify_new_feedback()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (
    user_id, title, message, type, reference_type, reference_id
  )
  select
    profile.id,
    'New user feedback',
    coalesce(sender.full_name, 'A user') || ' submitted ' || new.category || ' feedback.',
    'feedback',
    'feedback',
    new.id
  from public.profiles profile
  left join public.profiles sender on sender.id = new.user_id
  where profile.role::text = 'system_admin';
  return new;
end;
$$;

drop trigger if exists notify_new_feedback_trigger on public.feedback;
create trigger notify_new_feedback_trigger
after insert on public.feedback
for each row execute function public.notify_new_feedback();

create or replace function public.notify_feedback_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recipient_id uuid;
begin
  if new.legacy then
    return new;
  end if;

  select user_id into recipient_id
  from public.feedback
  where id = new.feedback_id;

  if recipient_id is not null and recipient_id is distinct from new.author_id then
    insert into public.notifications (
      user_id, title, message, type, reference_type, reference_id
    ) values (
      recipient_id,
      'Feedback reply received',
      'A system administrator replied to your feedback. Open My feedback to view the reply.',
      'feedback',
      'feedback',
      new.feedback_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_feedback_reply_trigger on public.feedback_replies;
create trigger notify_feedback_reply_trigger
after insert on public.feedback_replies
for each row execute function public.notify_feedback_reply();

commit;
