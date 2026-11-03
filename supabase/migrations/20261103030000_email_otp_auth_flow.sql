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
    -- During first-run setup, if expected_email is configured, only that email can request an OTP;
    -- if expected_email is not yet set, allow the first-run owner email to request an OTP.
    if v_expected_owner is null or v_expected_owner = '' or v_normalized = v_expected_owner then
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

create or replace function public.can_claim_initial_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(exists (
    select 1
    from public.initial_owner_setup s
    join auth.users u on u.id = auth.uid()
    where s.id = true
      and s.claimed_at is null
      and (s.expected_email is null or s.expected_email = '' or lower(u.email) = lower(trim(s.expected_email)))
      and u.email_confirmed_at is not null
      and not exists (select 1 from public.profiles p where p.role = 'owner')
  ), false);
$$;

create or replace function public.bootstrap_initial_owner(display_name_input text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_email text;
  v_expected_email text;
  v_claimed_at timestamptz;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(display_name_input, ''))) not between 1 and 160 then
    raise exception 'Name must contain 1 to 160 characters';
  end if;

  select expected_email, claimed_at
    into v_expected_email, v_claimed_at
    from public.initial_owner_setup where id = true for update;
  select lower(email) into v_email from auth.users
    where id = v_actor and email_confirmed_at is not null;

  if v_email is null or v_claimed_at is not null
     or (v_expected_email is not null and v_expected_email <> '' and v_email is distinct from lower(trim(v_expected_email)))
     or exists (select 1 from public.profiles where role = 'owner') then
    raise exception 'Initial Owner setup is not available for this account';
  end if;

  insert into public.profiles (user_id, email, display_name, role, staff_id, is_active, must_set_password)
    values (v_actor, v_email, trim(display_name_input), 'owner', null, true, false);

  update public.initial_owner_setup
    set expected_email = coalesce(nullif(trim(expected_email), ''), v_email),
        claimed_user_id = v_actor,
        claimed_at = now()
    where id = true and claimed_at is null;
  if not found then raise exception 'Initial Owner setup has already been claimed'; end if;

  insert into public.audit_events (actor_id, action, target_type, target_id)
    values (v_actor, 'owner.bootstrap', 'profile', v_actor);
end;
$$;

grant execute on function public.can_claim_initial_owner() to authenticated;
grant execute on function public.bootstrap_initial_owner(text) to authenticated;
revoke execute on function public.can_claim_initial_owner() from public, anon;
revoke execute on function public.bootstrap_initial_owner(text) from public, anon;


