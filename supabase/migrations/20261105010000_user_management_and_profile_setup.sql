-- Migration: User management enhancements (delete user account, self name setup, email-only invite)

-- 1. Update invite_user_direct to make display_name optional and default automatically
create or replace function public.invite_user_direct(
  email_input text,
  display_name_input text default null,
  role_input text default 'staff',
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

  -- Default name automatically if omitted (user sets up their own name upon login)
  if v_trimmed_name = '' then
    if role_input = 'staff' and staff_id_input is not null then
      select full_name into v_trimmed_name from public.staff where id = staff_id_input;
    end if;
    if coalesce(v_trimmed_name, '') = '' then
      if role_input = 'ceo' then
        v_trimmed_name := 'CEO';
      else
        v_trimmed_name := split_part(v_normalized_email, '@', 1);
      end if;
    end if;
  end if;

  if length(v_trimmed_name) > 160 then
    v_trimmed_name := substr(v_trimmed_name, 1, 160);
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

-- 2. Function to delete a user account (allows Owner to remove old email so it can be re-invited cleanly)
create or replace function public.delete_user_account(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_role text;
  v_email text;
begin
  if v_actor_id is null or not public.has_permission('users.manage') then
    raise exception 'Not authorized to manage users.';
  end if;

  select role, email into v_role, v_email from public.profiles where user_id = target_user_id;
  if v_role is null then
    raise exception 'Target account not found.';
  end if;

  if v_role = 'owner' or target_user_id = v_actor_id then
    raise exception 'The owner account cannot be deleted.';
  end if;

  -- Delete user permissions and profile
  delete from public.user_permissions where user_id = target_user_id;
  delete from public.profiles where user_id = target_user_id;

  -- Delete user from auth.users so the email can be re-invited from scratch
  delete from auth.users where id = target_user_id;

  insert into public.audit_events (actor_id, action, target_type, target_id, metadata)
  values (v_actor_id, 'user.delete', 'profile', target_user_id, jsonb_build_object('email', v_email, 'role', v_role));
end;
$$;

revoke all on function public.delete_user_account(uuid) from public, anon;
grant execute on function public.delete_user_account(uuid) to authenticated;

-- 3. Function allowing any authenticated user to update their own display name
create or replace function public.update_my_profile_name(display_name_input text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_trimmed text := trim(coalesce(display_name_input, ''));
begin
  if v_actor_id is null then
    raise exception 'Authentication required.';
  end if;

  if length(v_trimmed) < 1 or length(v_trimmed) > 160 then
    raise exception 'Name must contain 1 to 160 characters.';
  end if;

  update public.profiles
  set display_name = v_trimmed
  where user_id = v_actor_id and is_active = true;

  update auth.users
  set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('display_name', v_trimmed)
  where id = v_actor_id;
end;
$$;

revoke all on function public.update_my_profile_name(text) from public, anon;
grant execute on function public.update_my_profile_name(text) to authenticated;
