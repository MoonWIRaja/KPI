-- Migration: Direct user invitation via database RPC
-- Allows authorized Owners to invite CEO or Staff accounts directly without requiring Edge Function deployment.

create or replace function public.invite_user_direct(
  email_input text,
  display_name_input text,
  role_input text,
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
  -- 1. Authorization check
  if v_actor_id is null then
    raise exception 'Authentication required.';
  end if;

  if not public.has_permission('users.invite') then
    raise exception 'You do not have permission to invite users.';
  end if;

  -- 2. Input validation
  if v_normalized_email = '' or length(v_normalized_email) > 254 or v_normalized_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    raise exception 'Enter a valid email address.';
  end if;

  if length(v_trimmed_name) < 1 or length(v_trimmed_name) > 160 then
    raise exception 'Name must contain 1 to 160 characters.';
  end if;

  if role_input not in ('ceo', 'staff') then
    raise exception 'Role must be either CEO or Staff.';
  end if;

  -- 3. Role-specific validation
  if role_input = 'staff' then
    if staff_id_input is null then
      raise exception 'A staff account must be linked to a staff record.';
    end if;

    if not exists (select 1 from public.staff where id = staff_id_input and not is_archived) then
      raise exception 'The selected staff record was not found or is archived.';
    end if;

    if exists (select 1 from public.profiles where staff_id = staff_id_input) then
      raise exception 'This staff record already has an assigned user account.';
    end if;
  elsif role_input = 'ceo' then
    if staff_id_input is not null then
      raise exception 'A CEO account cannot be linked to an individual staff record.';
    end if;

    if exists (select 1 from public.profiles where role = 'ceo') then
      raise exception 'A CEO account already exists in the system.';
    end if;
  end if;

  -- 4. Check for existing profile with this email
  if exists (select 1 from public.profiles where lower(email) = v_normalized_email) then
    raise exception 'A user profile with this email address already exists.';
  end if;

  -- 5. Find or create user in auth.users
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

  -- 6. Create the user profile
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
    staff_id_input,
    true,
    false
  );

  -- 7. Record the audit event
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
    jsonb_build_object(
      'email', v_normalized_email,
      'role', role_input,
      'staff_id', staff_id_input
    )
  );

  return v_user_id;
end;
$$;

revoke all on function public.invite_user_direct(text, text, text, uuid) from public, anon;
grant execute on function public.invite_user_direct(text, text, text, uuid) to authenticated;
