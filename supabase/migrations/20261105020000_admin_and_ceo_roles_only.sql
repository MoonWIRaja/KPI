-- Migration: Restrict user accounts to CEO and Admin (staff do not have user accounts)

-- 1. Ensure profiles table accepts 'admin' as a valid role
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('owner', 'admin', 'ceo', 'staff'));

-- 2. Update has_permission so Admins and Owners have full system access
create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.is_active and not p.must_set_password and case
      when p.role in ('owner', 'admin') then true
      when p.role = 'ceo' and $1 not in ('users.manage', 'users.invite')
        then exists (
          select 1 from public.user_permissions up
          where up.user_id = p.user_id and up.permission_key = $1
        )
      when p.role = 'staff' and $1 in ('account.read.self', 'merit.read.self') then true
      else false
    end
    from public.profiles p where p.user_id = auth.uid()
  ), false);
$$;

-- 3. Update assign_default_permissions to assign full permissions for new CEO and Admin users
create or replace function public.assign_default_permissions()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.role in ('ceo', 'admin') then
    insert into public.user_permissions (user_id, permission_key) values
      (new.user_id, 'account.read.self'), (new.user_id, 'staff.read.all'),
      (new.user_id, 'staff.create'), (new.user_id, 'staff.update'),
      (new.user_id, 'staff.archive'), (new.user_id, 'staff.import'),
      (new.user_id, 'merit.read.all'), (new.user_id, 'merit.adjust'),
      (new.user_id, 'merit.correct'), (new.user_id, 'reports.read'),
      (new.user_id, 'reports.export'), (new.user_id, 'settings.manage'),
      (new.user_id, 'audit.read')
    on conflict do nothing;

    if new.role = 'admin' then
      insert into public.user_permissions (user_id, permission_key) values
        (new.user_id, 'users.manage'), (new.user_id, 'users.invite')
      on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

-- 4. Update invite_user_direct to enforce role in ('ceo', 'admin') and eliminate staff requirement
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
