-- Migration: Fix invited user auth identities to enable Supabase OTP login & email delivery

-- 1. Backfill any existing users in auth.users who are missing a record in auth.identities
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) then
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
      select
        u.id::text,
        u.id::text,
        u.id,
        jsonb_build_object(''sub'', u.id::text, ''email'', lower(u.email)),
        ''email'',
        now(),
        now(),
        now()
      from auth.users u
      where not exists (
        select 1 from auth.identities i
        where i.user_id = u.id and i.provider = ''email''
      )
      on conflict do nothing';
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
      select
        u.id::text,
        u.id,
        jsonb_build_object(''sub'', u.id::text, ''email'', lower(u.email)),
        ''email'',
        now(),
        now(),
        now()
      from auth.users u
      where not exists (
        select 1 from auth.identities i
        where i.user_id = u.id and i.provider = ''email''
      )
      on conflict do nothing';
  end if;
end $$;

-- 2. Update invite_user_direct to always ensure auth.identities is populated
create or replace function public.invite_user_direct(
  email_input text,
  display_name_input text default null,
  role_input text default 'admin',
  staff_id_input uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_normalized_email text := lower(trim(coalesce(email_input, '')));
  v_trimmed_name text := trim(coalesce(display_name_input, ''));
  v_user_id uuid;
begin
  if v_actor_id is null then
    raise exception 'Authentication required.';
  end if;

  if not public.has_permission('users.invite') then
    raise exception 'You do not have permission to invite users.';
  end if;

  if v_normalized_email = '' or length(v_normalized_email) > 254 or v_normalized_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    raise exception 'Enter a valid email address.';
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
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_normalized_email,
      '',
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('display_name', v_trimmed_name),
      now(),
      now()
    );
  else
    update auth.users
    set email_confirmed_at = coalesce(email_confirmed_at, now()),
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('display_name', v_trimmed_name),
        updated_at = now()
    where id = v_user_id;
  end if;

  -- Ensure auth.identities has matching email identity for OTP authentication
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
  ) then
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
    using v_user_id::text, v_user_id::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_normalized_email);
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
    using v_user_id::text, v_user_id, jsonb_build_object('sub', v_user_id::text, 'email', v_normalized_email);
  end if;

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

