-- Migration: Support Email OTP login and restrict OTP requests to invited / active accounts only

create or replace function public.can_request_otp(email_input text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_normalized text := lower(trim(coalesce(email_input, '')));
  v_setup_complete boolean := false;
  v_expected_owner text;
begin
  if v_normalized = '' or length(v_normalized) > 254 then
    return false;
  end if;

  -- 1. Check if first-run owner setup is still open
  select coalesce(claimed_at is not null, false), lower(trim(coalesce(expected_email, '')))
    into v_setup_complete, v_expected_owner
    from public.initial_owner_setup
    where id = true;

  if not coalesce(v_setup_complete, false) then
    -- During first-run setup, only the expected owner email can request an OTP
    if v_expected_owner is not null and v_expected_owner <> '' and v_normalized = v_expected_owner then
      return true;
    end if;
  end if;

  -- 2. For standard operation, check if user has an active profile
  if exists (
    select 1
    from public.profiles
    where lower(email) = v_normalized
      and is_active = true
  ) then
    return true;
  end if;

  -- 3. Check if user is in auth.users as an invited user
  if exists (
    select 1
    from auth.users u
    join public.profiles p on p.user_id = u.id
    where lower(u.email) = v_normalized
      and p.is_active = true
      and (u.banned_until is null or u.banned_until < now())
  ) then
    return true;
  end if;

  return false;
end;
$$;

revoke all on function public.can_request_otp(text) from public;
grant execute on function public.can_request_otp(text) to anon, authenticated;

