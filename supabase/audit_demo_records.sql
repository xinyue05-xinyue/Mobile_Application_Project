with event_state as (
  select
    event.*,
    case
      when event.status = 'cancelled' then 'cancelled'
      when event.ends_at <= now() then 'ended'
      when event.starts_at <= now() then 'in_progress'
      else 'upcoming'
    end as expected_status
  from public.donation_events event
), latest_role_request as (
  select request.*
  from (
    select
      role_request.*,
      row_number() over (
        partition by role_request.user_id
        order by role_request.created_at desc, role_request.id desc
      ) as request_number
    from public.role_requests role_request
  ) request
  where request.request_number = 1
), findings as (
  select
    'HIGH'::text as severity,
    'EVENT_STATUS_DOES_NOT_MATCH_DATE'::text as issue,
    event.id as record_id,
    event.title as record_name,
    'Stored=' || event.status || ', expected=' || event.expected_status ||
      ', starts=' || event.starts_at::text || ', ends=' || event.ends_at::text as details
  from event_state event
  where event.status <> event.expected_status

  union all

  select
    'HIGH',
    'VERIFIED_DONATION_FOR_FUTURE_EVENT',
    donation.id,
    event.title,
    'Donation date=' || donation.donation_date::text ||
      ', event starts=' || event.starts_at::text || ', event status=' || event.status
  from public.donations donation
  join public.donation_events event on event.id = donation.event_id
  where donation.verification_status::text = 'verified'
    and (event.starts_at > now() or event.status = 'upcoming')

  union all

  select
    'HIGH',
    'ATTENDANCE_FOR_FUTURE_EVENT',
    registration.id,
    event.title,
    'Registration status=' || registration.status ||
      ', attended=' || coalesce(registration.attended_at::text, 'NULL') ||
      ', event starts=' || event.starts_at::text
  from public.event_registrations registration
  join public.donation_events event on event.id = registration.event_id
  where registration.status = 'attended'
    and (event.starts_at > now() or event.status = 'upcoming')

  union all

  select
    'HIGH',
    'VERIFIED_EVENT_DONATION_WITHOUT_ATTENDANCE',
    donation.id,
    event.title,
    'Donor=' || donation.donor_id::text || ', donation date=' || donation.donation_date::text
  from public.donations donation
  join public.donation_events event on event.id = donation.event_id
  left join public.event_registrations registration
    on registration.event_id = donation.event_id
   and registration.donor_id = donation.donor_id
   and registration.status = 'attended'
  where donation.verification_status::text = 'verified'
    and registration.id is null

  union all

  select
    'MEDIUM',
    'ATTENDANCE_WITHOUT_VERIFIED_DONATION',
    registration.id,
    event.title,
    'Donor=' || registration.donor_id::text ||
      ', attended=' || coalesce(registration.attended_at::text, 'NULL')
  from public.event_registrations registration
  join public.donation_events event on event.id = registration.event_id
  left join public.donations donation
    on donation.event_id = registration.event_id
   and donation.donor_id = registration.donor_id
   and donation.verification_status::text = 'verified'
  where registration.status = 'attended'
    and donation.id is null

  union all

  select
    'HIGH',
    'VERIFIED_EMERGENCY_DONATION_WITHOUT_COMPLETED_RESPONSE',
    donation.id,
    'Emergency request ' || request.id::text,
    'Donor=' || donation.donor_id::text || ', donation date=' || donation.donation_date::text
  from public.donations donation
  join public.emergency_requests request on request.id = donation.emergency_request_id
  left join public.emergency_responses response
    on response.request_id = donation.emergency_request_id
   and response.donor_id = donation.donor_id
   and response.status = 'completed'
  where donation.verification_status::text = 'verified'
    and response.id is null

  union all

  select
    'HIGH',
    'DONATION_LINKED_TO_TWO_SOURCES',
    donation.id,
    'Donation',
    'event_id=' || donation.event_id::text ||
      ', emergency_request_id=' || donation.emergency_request_id::text
  from public.donations donation
  where donation.event_id is not null
    and donation.emergency_request_id is not null

  union all

  select
    'MEDIUM',
    'VERIFIED_DONATION_MISSING_VERIFICATION_DETAILS',
    donation.id,
    'Donation',
    'verified_by=' || coalesce(donation.verified_by::text, 'NULL') ||
      ', verified_at=' || coalesce(donation.verified_at::text, 'NULL')
  from public.donations donation
  where donation.verification_status::text = 'verified'
    and (donation.verified_by is null or donation.verified_at is null)

  union all

  select
    'MEDIUM',
    'ACTIVE_REGISTRATION_ALREADY_ENDED',
    registration.id,
    event.title,
    'Registration status=' || registration.status || ', event ended=' || event.ends_at::text
  from public.event_registrations registration
  join public.donation_events event on event.id = registration.event_id
  where registration.status = 'registered'
    and (event.ends_at <= now() or event.status in ('ended', 'cancelled'))

  union all

  select
    'MEDIUM',
    'ACTIVE_EMERGENCY_RESPONSE_ALREADY_EXPIRED',
    response.id,
    'Emergency request ' || request.id::text,
    'Response status=' || response.status || ', deadline=' || request.deadline::text
  from public.emergency_responses response
  join public.emergency_requests request on request.id = response.request_id
  where response.status = 'pending'
    and (request.deadline <= now() or request.status::text <> 'active')

  union all

  select
    'HIGH',
    'REDEMPTION_POINTS_DO_NOT_MATCH_REWARD',
    redemption.id,
    item.name,
    'Spent=' || redemption.points_spent::text || ', reward cost=' || item.points_cost::text
  from public.reward_redemptions redemption
  join public.reward_items item on item.id = redemption.reward_item_id
  where redemption.points_spent <> item.points_cost

  union all

  select
    'HIGH',
    'REDEMPTION_MISSING_POINTS_TRANSACTION',
    redemption.id,
    item.name,
    'Donor=' || redemption.donor_id::text || ', spent=' || redemption.points_spent::text
  from public.reward_redemptions redemption
  join public.reward_items item on item.id = redemption.reward_item_id
  left join public.reward_transactions transaction
    on transaction.redemption_id = redemption.id
   and transaction.transaction_type = 'redeemed'
  where transaction.id is null

  union all

  select
    'HIGH',
    'APPROVED_APPLICATION_BUT_USER_IS_DONOR',
    request.id,
    profile.full_name,
    'Requested role=' || request.requested_role::text || ', profile role=' || profile.role::text
  from latest_role_request request
  join public.profiles profile on profile.id = request.user_id
  where request.status = 'approved'
    and profile.role::text = 'donor'

  union all

  select
    'HIGH',
    'REMOVED_APPLICATION_BUT_USER_IS_STILL_STAFF',
    request.id,
    profile.full_name,
    'Application status=removed, profile role=' || profile.role::text
  from latest_role_request request
  join public.profiles profile on profile.id = request.user_id
  where request.status = 'removed'
    and profile.role::text <> 'donor'

  union all

  select
    'LOW',
    'RESOLVED_FEEDBACK_WITHOUT_REPLY',
    feedback.id,
    feedback.category,
    'Feedback is resolved but has no saved reply.'
  from public.feedback feedback
  left join public.feedback_replies reply on reply.feedback_id = feedback.id
  where feedback.status = 'resolved'
  group by feedback.id, feedback.category
  having count(reply.id) = 0
)
select severity, issue, record_id, record_name, details
from findings
order by
  case severity when 'HIGH' then 1 when 'MEDIUM' then 2 else 3 end,
  issue,
  record_name;
