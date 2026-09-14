begin;

alter table public.organisation_profiles
drop constraint if exists organisation_profiles_contact_phone_format_check;

alter table public.organisation_profiles
add constraint organisation_profiles_contact_phone_format_check
check (contact_phone is null or contact_phone ~ '^0[0-9]{9,10}$') not valid;

commit;
