-- Migration: Fix invite_user_direct to leave email_confirmed_at NULL
-- so GoTrue can process signInWithOtp without "Database error finding user"
--
-- Root cause: email_confirmed_at = now() + encrypted_password = '' causes GoTrue
-- to crash internally when OTP is requested because it tries to update user state
-- but cannot handle empty password + already-confirmed state combination.
--
-- Fix: Set email_confirmed_at = NULL on invite so GoTrue treats user as
-- "pending confirmation" and can send OTP normally. After user verifies OTP,
-- GoTrue sets email_confirmed_at automatically.

-- 1. Fix existing invited users who have empty password but email_confirmed_at set
--    Reset them to unconfirmed so OTP works
update auth.users
set email_confirmed_at = null,
    updated_at = now()
where encrypted_password = ''
  and email_confirmed_at is not null
  and id in (
    select user_id from public.profiles where role in ('ceo', 'admin')
  );

-- 2. Replace invite_user_direct to set email_confirmed_at = NULL
create or replace function public.invite_user_direct(
  email_input text,
  role_input text,
  display_name_input text default '',
  actor_user_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid;
  v_normalized_email text;
  v_trimmed_name text;
  v_user_id uuid;
  v_id_type text;
  v_has_provider_id boolean;
begin
  -- Resolve actor
  v_actor_id := coalesce(actor_user_id, auth.uid());
  if v_actor_id is null then
    raise exception 'Authentication required.';
  end if;

  -- Validate actor is owner or admin
  if not exists (
    select 1 from public.profiles
    where user_id = v_actor_id
      and role in ('owner', 'admin')
      and is_active = true
  ) then
    raise exception 'Only owners or admins can invite users.';
  end if;

  v_normalized_email := lower(trim(email_input));
  v_trimmed_name := trim(coalesce(display_name_input, ''));

  if v_normalized_email = '' then
    raise exception 'Email address is required.';
  end if;

  if role_input not in ('ceo', 'admin') then
    raise exception 'Role must be either CEO or Admin.';
  end if;

  if v_trimmed_name = '' then
    if role_input = 'ceo' then
      v_trimmed_name := 'CEO';
    elsif role_input = 'admin' then
      v_trimmed_name := 'Admin';
    else
      v_trimmed_name := split_part(v_normalized_email, '@', 1);
    end if;
  end if;

  if length(v_trimmed_name) > 160 then
    v_trimmed_name := substr(v_trimmed_name, 1, 160);
  end if;

  if role_input = 'ceo' and exists (select 1 from public.profiles where role = 'ceo') then
    raise exception 'A CEO account already exists in the system.';
  end if;

  if exists (select 1 from public.profiles where lower(email) = v_normalized_email) then
    raise exception 'A user profile with this email address already exists.';
  end if;

  -- Find or create user in auth.users
  select id into v_user_id from auth.users where lower(email) = v_normalized_email limit 1;

  if v_user_id is null then
    v_user_id := gen_random_uuid();
    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,  -- NULL: let GoTrue confirm after OTP verification
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_normalized_email,
      '',
      null,  -- KEY FIX: NULL instead of now() so GoTrue can process OTP
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('display_name', v_trimmed_name),
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  else
    -- User exists in auth.users: reset to unconfirmed so OTP works
    update auth.users
    set email_confirmed_at = null,
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('display_name', v_trimmed_name),
        confirmation_token = coalesce(confirmation_token, ''),
        recovery_token = coalesce(recovery_token, ''),
        email_change = coalesce(email_change, ''),
        email_change_token_new = coalesce(email_change_token_new, ''),
        updated_at = now()
    where id = v_user_id;
  end if;

  -- Ensure auth.identities has matching email identity
  select data_type into v_id_type
  from information_schema.columns
  where table_schema = 'auth' and table_name = 'identities' and column_name = 'id';

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) into v_has_provider_id;

  if v_has_provider_id then
    if v_id_type = 'uuid' then
      execute '
        insert into auth.identities (
          id,
          provider_id,
          user_id,
          identity_data,
          provider,
          last_sign_in_at,
          created_at,
          updated_at
        )
        values (gen_random_uuid(), $1, $2, $3, ''email'', now(), now(), now())
        on conflict do nothing'
      using v_user_id::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_normalized_email, 'email_verified', false);
    else
      execute '
        insert into auth.identities (
          id,
          provider_id,
          user_id,
          identity_data,
          provider,
          last_sign_in_at,
          created_at,
          updated_at
        )
        values ($1, $2, $3, $4, ''email'', now(), now(), now())
        on conflict do nothing'
      using v_user_id::text, v_user_id::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_normalized_email, 'email_verified', false);
    end if;
  else
    execute '
      insert into auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
      )
      values ($1, $2, $3, ''email'', now(), now(), now())
      on conflict do nothing'
    using v_user_id::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_normalized_email, 'email_verified', false);
  end if;

  -- Create profile record
  insert into public.profiles (
    user_id,
    email,
    display_name,
    role,
    staff_id,
    is_active,
    must_set_password
  ) values (
    v_user_id,
    v_normalized_email,
    v_trimmed_name,
    role_input,
    null,
    true,
    false
  );

  -- Audit log
  insert into public.audit_events (
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  ) values (
    v_actor_id,
    'user.invite',
    'profile',
    v_user_id,
    jsonb_build_object('email', v_normalized_email, 'role', role_input)
  );

  return v_user_id;
end;
$$;

revoke all on function public.invite_user_direct(text, text, text, uuid) from public, anon;
grant execute on function public.invite_user_direct(text, text, text, uuid) to authenticated;
